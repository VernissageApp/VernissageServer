//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Queues
import ActivityPubKit

extension Application.Services {
    struct ActivityPubServiceKey: StorageKey {
        typealias Value = ActivityPubServiceType
    }

    var activityPubService: ActivityPubServiceType {
        get {
            self.application.storage[ActivityPubServiceKey.self] ?? ActivityPubService()
        }
        nonmutating set {
            self.application.storage[ActivityPubServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ActivityPubServiceType: Sendable {
    func delete(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
    func create(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
    func follow(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
    func accept(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
    func reject(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
    func undo(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
    func like(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
    func announce(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
    func isDomainBlockedByInstance(actorId: String, on context: ExecutionContext) async throws -> Bool
    func isDomainBlockedByInstance(activity: ActivityDto, on context: ExecutionContext) async throws -> Bool
    func downloadStatus(activityPubId: String, on context: ExecutionContext) async throws -> Status
}

/// Service responsible for consuming requests retrieved on Activity Pub controllers from remote instances.
final class ActivityPubService: ActivityPubServiceType {

    public func delete(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let statusesService = context.services.statusesService
        let usersService = context.services.usersService
        let activityPubSignatureService = context.services.activityPubSignatureService
        
        let objects = activityPubRequest.activity.object.objects()
        for object in objects {
            switch object.type {
            case .some(.note), .some(.tombstone):
                context.logger.info("Deleting status: '\(object.id)'.")
                guard let statusToDelete = try await statusesService.get(activityPubId: object.id, on: context.db) else {
                    context.logger.info("Deleting status: '\(object.id)'. Status not exists in local database.")
                    continue
                }
                
                guard statusToDelete.isLocal == false else {
                    context.logger.info("Deleting status: '\(object.id)'. Cannot deletee local status from ActivityPub request.")
                    continue
                }
                
                // Validate signature (also with users downloaded from remote server).
                try await activityPubSignatureService.validateSignature(activityPubRequest: activityPubRequest, on: context)
                
                // Signature verified, we can delete status.
                try await statusesService.delete(id: statusToDelete.requireID(), on: context.application.db)
                context.logger.info("Deleting status: '\(object.id)'. Status deleted from local database successfully.")
            case .none, .some(.profile):
                context.logger.info("Deleting user: '\(object.id)'.")
                guard let userToDelete = try await usersService.get(activityPubProfile: object.id, on: context.application.db) else {
                    context.logger.info("Deleting user: '\(object.id)'. User not exists in local database.")
                    continue
                }
                
                guard userToDelete.isLocal == false else {
                    context.logger.info("Deleting user: '\(object.id)'. Cannot delete local user from ActivityPub request.")
                    continue
                }
                
                // Validate signature with local database only (user has been alredy removed from remote).
                try await activityPubSignatureService.validateLocalSignature(activityPubRequest: activityPubRequest, on: context)

                // Signature verified, we have to delete all user's statuses first.
                try await statusesService.delete(owner: userToDelete.requireID(), on: context)
                
                // Now we can delete user (and all user's references) from database.
                try await usersService.delete(remoteUser: userToDelete, on: context.application.db)
                context.logger.info("Deleting user: '\(object.id)'. User deleted from local database successfully.")
            default:
                context.logger.warning("Deleting object type: '\(object.type?.rawValue ?? "<unknown>")' is not supported yet.",
                                       metadata: [Constants.requestMetadata: activityPubRequest.bodyValue.loggerMetadata()])
            }
        }
    }
    
    public func create(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let statusesService = context.services.statusesService
        let searchService = context.services.searchService
        let activity = activityPubRequest.activity
        
        let objects = activity.object.objects()
        for object in objects {
            switch object.type {
            case .note:
                guard let noteDto = object.object as? NoteDto else {
                    context.logger.warning("Cannot cast note type object to NoteDto (activity: \(activity.id).")
                    continue
                }
                
                guard let activityPubProfile = activity.actor.actorIds().first else {
                    context.logger.warning("Cannot find any ActivityPub actor profile id (activity: \(activity.id)).")
                    continue
                }
                
                // Validations for regular status (with images).
                if noteDto.isComment() == false {
                    
                    // Prevent creating new statuses when status doesn't contains any image.
                    if noteDto.attachment?.contains(where: { $0.mediaType.starts(with: "image/") }) == false {
                        context.logger.warning("Status doesn't contain any image media type attachments (activity: \(activity.id)).")
                        continue
                    }
                    
                    // Prevent creating new statuses when author is not followed by anyone in the instance.
                    let isRemoteUserFollowedByAnyone = try await self.isRemoteUserFollowedByAnyone(activityPubProfile: activityPubProfile, on: context)
                    if isRemoteUserFollowedByAnyone == false {
                        context.logger.warning("Author of the status is not followed by anyone on the instance (activity: \(activity.id)).")
                        continue
                    }
                }
                
                // Validation for statuses which are comments to other statuses.
                if noteDto.isComment() == true {
                    
                    // Prevent creating new statuses (comments) whene there is no commented (parent) status.
                    let isParentStatusInDatabase = try await self.isParentStatusInDatabase(replyToActivityPubId: noteDto.inReplyTo, on: context)
                    if isParentStatusInDatabase == false {
                        context.logger.warning("Parent status '\(noteDto.inReplyTo ?? "")' for comment doesn't exists in the database (activity: \(activity.id)).")
                        continue
                    }
                }
                
                // Download user data (who created status) to local database.
                guard let user = try await searchService.downloadRemoteUser(activityPubProfile: activityPubProfile, on: context) else {
                    context.logger.warning("User '\(activity.actor.actorIds().first ?? "")' cannot found in the local database (activity: \(activity.id)).")
                    continue
                }
                
                // Create status into database.
                let statusFromDatabase = try await statusesService.create(basedOn: noteDto, userId: user.requireID(), on: context)
                
                // Recalculate numer of user statuses.
                try await statusesService.updateStatusCount(for: user.requireID(), on: context.application.db)
                
                // Add new status to user's timelines (except comments).
                if statusFromDatabase.$replyToStatus.id == nil {
                    try await statusesService.createOnLocalTimeline(followersOf: user.requireID(), status: statusFromDatabase, on: context)
                }
            default:
                context.logger.warning("Object type: '\(object.type?.rawValue ?? "<unknown>")' is not supported yet.",
                                       metadata: [Constants.requestMetadata: activityPubRequest.bodyValue.loggerMetadata()])
            }
        }
    }
    
    public func follow(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let activity = activityPubRequest.activity
        let actorIds = activity.actor.actorIds()
        
        for actorId in actorIds {
            let objects = activity.object.objects()
            for object in objects {
                let domainIsBlockedByUser = try await self.isDomainBlockedByUser(actorId: object.id, on: context)
                guard domainIsBlockedByUser == false else {
                    context.logger.notice("Actor's domain: '\(actorId)' is blocked by user's (\(object.id)) domain blocks.")
                    continue
                }
                
                try await self.follow(sourceProfileUrl: actorId, activityPubObject: object, activityId: activity.id, on: context)
            }
        }
    }
    
    public func accept(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let activity = activityPubRequest.activity
        let actorIds = activity.actor.actorIds()

        for targetActorId in actorIds {
            let objects = activity.object.objects()
            for object in objects {
                try await self.accept(targetProfileUrl: targetActorId, activityPubObject: object, on: context)
            }
        }
    }

    public func reject(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let activity = activityPubRequest.activity
        let actorIds = activity.actor.actorIds()

        for targetActorId in actorIds {
            let objects = activity.object.objects()
            for object in objects {
                try await self.reject(targetProfileUrl: targetActorId, activityPubObject: object, on: context)
            }
        }
    }
    
    func undo(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let activity = activityPubRequest.activity
        let objects = activity.object.objects()

        for object in objects {
            switch object.type {
            case .follow:
                for sourceActorId in activity.actor.actorIds() {
                    try await self.unfollow(sourceActorId: sourceActorId, activityPubObject: object, on: context)
                }
            case .announce:
                for sourceActorId in activity.actor.actorIds() {
                    try await self.unannounce(sourceActorId: sourceActorId, activityPubObject: object, on: context)
                }
            case .like:
                for sourceActorId in activity.actor.actorIds() {
                    try await self.unlike(sourceActorId: sourceActorId, activityPubObject: object, on: context)
                }
            default:
                context.logger.warning("Undo of '\(object.type?.rawValue ?? "<unknown>")' action is not supported yet",
                                       metadata: [Constants.requestMetadata: activityPubRequest.bodyValue.loggerMetadata()])
            }
        }
    }
    
    public func like(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let statusesService = context.services.statusesService
        let searchService = context.services.searchService
        let activity = activityPubRequest.activity
                
        // Download user data (who liked status) to local database.
        guard let actorActivityPubId = activity.actor.actorIds().first,
              let remoteUser = try await searchService.downloadRemoteUser(activityPubProfile: actorActivityPubId, on: context) else {
            context.logger.warning("User '\(activity.actor.actorIds().first ?? "")' cannot found in the local database.")
            return
        }
        
        let remoteUserId = try remoteUser.requireID()
                
        let objects = activity.object.objects()
        for object in objects {
            // Statuses favourited by remote users have to exists in the local database.
            guard let status = try await statusesService.get(activityPubId: object.id, on: context.db) else {
                context.logger.info("Status '\(object.id)' not exists in local database. Thus cannot by favourited by user '\(remoteUserId)'.")
                continue
            }

            let statusId = try status.requireID()
            let targetUserId = status.$user.id
            
            // Break when status has been already favourited by user.
            let statusFavouriteFromDatabase = try await StatusFavourite.query(on: context.db)
                .filter(\.$status.$id == statusId)
                .filter(\.$user.$id == remoteUserId)
                .first()

            if statusFavouriteFromDatabase != nil {
                context.logger.info("Status '\(statusId)' has been already favourited by user '\(remoteUserId)' in local database.")
                continue
            }
            
            // Create favourite.
            let id = context.services.snowflakeService.generate()
            let statusFavourite = StatusFavourite(id: id, statusId: statusId, userId: remoteUserId)
            try await statusFavourite.create(on: context.db)
            
            context.logger.info("Recalculating favourites for status '\(statusId)' in local database.")
            try await statusesService.updateFavouritesCount(for: statusId, on: context.db)
            
            // Send notification to user about new like.
            let notificationsService = context.services.notificationsService
            let usersService = context.services.usersService

            if let targetUser = try await usersService.get(id: targetUserId, on: context.db) {
                // We have to download ancestors when favourited is comment (in notifications screen we can show main photo which is favourited).
                let ancestors = try await statusesService.ancestors(for: statusId, on: context.db)
                
                // Create notification.
                try await notificationsService.create(type: .favourite,
                                                      to: targetUser,
                                                      by: remoteUser.requireID(),
                                                      statusId: statusId,
                                                      mainStatusId: ancestors.first?.id,
                                                      on: context)
            }
        }
    }
    
    private func unlike(sourceActorId: String, activityPubObject: ObjectDto, on context: ExecutionContext) async throws {
        guard let annouceDto = activityPubObject.object as? LikeDto,
              let objects = annouceDto.object?.objects() else {
            return
        }
        
        for object in objects {
            try await self.unlike(sourceProfileUrl: sourceActorId, activityPubObject: object, on: context)
        }
    }
    
    private func unlike(sourceProfileUrl: String, activityPubObject: ObjectDto, on context: ExecutionContext) async throws {
        context.logger.info("Unliking status: '\(activityPubObject.id)' by account '\(sourceProfileUrl)' (from remote server).")
        let statusesService = context.services.statusesService
        let usersService = context.services.usersService
        
        guard let user = try await usersService.get(activityPubProfile: sourceProfileUrl, on: context.db) else {
            context.logger.warning("Cannot find user '\(sourceProfileUrl)' in local database.")
            return
        }
        
        guard let status = try await statusesService.get(activityPubId: activityPubObject.id, on: context.db) else {
            context.logger.warning("Cannot find orginal status '\(activityPubObject.id)' in local database.")
            return
        }
        
        let statusId = try status.requireID()
        let userId = try user.requireID()
        
        guard let statusFavourite = try await StatusFavourite.query(on: context.db)
            .filter(\.$status.$id == statusId)
            .filter(\.$user.$id == userId)
            .first() else {
            context.logger.warning("Cannot find favourite for status '\(statusId)' and user '\(userId)' in local database.")
            return
        }
                
        context.logger.info("Deleting favourite for status '\(statusId)' and user '\(userId)' from local database.")
        try await statusFavourite.delete(on: context.db)
        
        context.logger.info("Recalculating favourites for status '\(statusId)' in local database.")
        try await statusesService.updateFavouritesCount(for: statusId, on: context.db)
    }
    
    public func announce(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let statusesService = context.services.statusesService
        let usersService = context.services.usersService
        let activity = activityPubRequest.activity
        let objects = activity.object.objects()
        let appplicationSettings = context.application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""

        guard let actorActivityPubId = activity.actor.actorIds().first else {
            context.logger.warning("Cannot find any ActivityPub actor profile id (activity: \(activity.id)).")
            return
        }
        
        let isRemoteUserFollowedByAnyone = try await self.isRemoteUserFollowedByAnyone(activityPubProfile: actorActivityPubId, on: context)
        let isLocalObjectOnTheList = self.isLocalObjectOnTheList(objects: objects, baseAddress: baseAddress)
        
        if isRemoteUserFollowedByAnyone == false && isLocalObjectOnTheList == false {
            context.logger.warning("Author of the boost is not followed by anyone on the instance and the boosted status is not local status (activity: \(activity.id)).")
            return
        }
        
        guard let remoteUser = try await usersService.get(activityPubProfile: actorActivityPubId, on: context.db) else {
            context.logger.warning("User '\(activity.actor.actorIds().first ?? "")' cannot found in the local database (activity: \(activity.id)).")
            return
        }
        
        for object in objects {
            // Create (or get from local database) main status in local database.
            let downloadedStatus = try await self.downloadStatusWithoutAttachmentsError(activityPubId: object.id, on: context)
            guard let downloadedStatus else {
                context.logger.warning("Boosted status '\(object.id)' has not been downloaded because it's not an image (activity: \(activity.id)).")
                continue
            }
                        
            // Get full status from database.
            guard let mainStatusFromDatabase = try await statusesService.getOrginalStatus(id: downloadedStatus.requireID(), on: context.db) else {
                context.logger.warning("Boosted status '\(object.id)' has not been downloaded successfully (activity: \(activity.id)).")
                continue
            }
            
            // We shouldn't show boosted statuses without attachments on timeline.
            if mainStatusFromDatabase.attachments.isEmpty {
                context.logger.warning("Boosted status '\(object.id)' doesn't contains any images (activity: \(activity.id)).")
                continue
            }
                        
            // Create reblog status.
            let statusId = context.application.services.snowflakeService.generate()
            let reblogStatus = try Status(id: statusId,
                                          isLocal: false,
                                          userId: remoteUser.requireID(),
                                          note: nil,
                                          baseAddress: baseAddress,
                                          userName: remoteUser.userName,
                                          application: nil,
                                          categoryId: nil,
                                          visibility: .public,
                                          reblogId: mainStatusFromDatabase.requireID(),
                                          publishedAt: Date())
            
            try await reblogStatus.create(on: context.db)
            try await statusesService.updateReblogsCount(for: mainStatusFromDatabase.requireID(), on: context.db)
            
            // Add new notification (when remote user reblog local status).
            if mainStatusFromDatabase.isLocal {
                let notificationsService = context.application.services.notificationsService
                try await notificationsService.create(type: .reblog,
                                                      to: mainStatusFromDatabase.user,
                                                      by: remoteUser.requireID(),
                                                      statusId: mainStatusFromDatabase.requireID(),
                                                      mainStatusId: nil,
                                                      on: context)
            }
            
            // Add new reblog status to user's timelines.
            context.logger.info("Connecting status '\(reblogStatus.stringId() ?? "")' to followers of '\(remoteUser.stringId() ?? "")'.")
            try await statusesService.createOnLocalTimeline(followersOf: remoteUser.requireID(), status: reblogStatus, on: context)
        }
    }
    
    private func downloadStatusWithoutAttachmentsError(activityPubId: String, on context: ExecutionContext) async throws -> Status? {
        do {
            let downloadedStatus = try await self.downloadStatus(activityPubId: activityPubId, on: context)
            return downloadedStatus
        } catch ActivityPubError.missingAttachments {
            // Consume this kind of error (it’s not a real error - statuses without images are simply not supported).
        }
        
        return nil
    }
    
    private func unannounce(sourceActorId: String, activityPubObject: ObjectDto, on context: ExecutionContext) async throws {
        guard let annouceDto = activityPubObject.object as? AnnouceDto,
              let objects = annouceDto.object?.objects() else {
            return
        }
        
        for object in objects {
            try await self.unannounce(sourceProfileUrl: sourceActorId, activityPubObject: object, on: context)
        }
    }
    
    private func unannounce(sourceProfileUrl: String, activityPubObject: ObjectDto, on context: ExecutionContext) async throws {
        context.logger.info("Unannoucing status: '\(activityPubObject.id)' by account '\(sourceProfileUrl)' (from remote server).")
        let statusesService = context.services.statusesService
        let usersService = context.services.usersService
        
        guard let user = try await usersService.get(activityPubProfile: sourceProfileUrl, on: context.db) else {
            context.logger.warning("Cannot find user '\(sourceProfileUrl)' in local database.")
            return
        }
        
        guard let orginalStatus = try await statusesService.get(activityPubId: activityPubObject.id, on: context.db) else {
            context.logger.warning("Cannot find orginal status '\(activityPubObject.id)' in local database.")
            return
        }
        
        let orginalStatusId = try orginalStatus.requireID()
        let userId = try user.requireID()
        
        guard let status = try await Status.query(on: context.db)
            .filter(\.$reblog.$id == orginalStatusId)
            .filter(\.$user.$id == userId)
            .first() else {
            context.logger.warning("Cannot find rebloging status '\(orginalStatusId)' for user '\(userId)' in local database.")
            return
        }
        
        let statusId = try status.requireID()
        context.logger.info("Deleting status '\(statusId)' (reblog) from local database.")
        try await statusesService.delete(id: statusId, on: context.db)
        
        context.logger.info("Recalculating reblogs for orginal status '\(orginalStatusId)' in local database.")
        try await statusesService.updateReblogsCount(for: orginalStatusId, on: context.db)
    }
    
    private func unfollow(sourceActorId: String, activityPubObject: ObjectDto, on context: ExecutionContext) async throws {
        guard let followDto = activityPubObject.object as? FollowDto,
              let objects = followDto.object?.objects() else {
            return
        }
        
        for object in objects {
            try await self.unfollow(sourceProfileUrl: sourceActorId, activityPubObject: object, on: context)
        }
    }
    
    private func unfollow(sourceProfileUrl: String, activityPubObject: ObjectDto, on context: ExecutionContext) async throws {
        context.logger.info("Unfollowing account: '\(activityPubObject.id)' by account '\(sourceProfileUrl)' (from remote server).")

        let followsService = context.services.followsService
        let usersService = context.services.usersService
        
        let sourceUser = try await usersService.get(activityPubProfile: sourceProfileUrl, on: context.db)
        guard let sourceUser else {
            context.logger.warning("Cannot find user '\(sourceProfileUrl)' in local database.")
            return
        }
        
        let targetUser = try await usersService.get(activityPubProfile: activityPubObject.id, on: context.application.db)
        guard let targetUser else {
            context.logger.warning("Cannot find user '\(activityPubObject.id)' in local database.")
            return
        }
        
        _ = try await followsService.unfollow(sourceId: sourceUser.requireID(), targetId: targetUser.requireID(), on: context)
        try await usersService.updateFollowCount(for: sourceUser.requireID(), on: context.db)
        try await usersService.updateFollowCount(for: targetUser.requireID(), on: context.db)
    }
    
    private func follow(sourceProfileUrl: String, activityPubObject: ObjectDto, activityId: String, on context: ExecutionContext) async throws {
        context.logger.info("Following account: '\(activityPubObject.id)' by account '\(sourceProfileUrl)' (from remote server).")

        let searchService = context.services.searchService
        let followsService = context.services.followsService
        let usersService = context.services.usersService

        // Download profile from remote server.
        context.logger.info("Downloading account \(sourceProfileUrl) from remote server.")

        let remoteUser = try await searchService.downloadRemoteUser(activityPubProfile: sourceProfileUrl, on: context)
        guard let remoteUser else {
            context.logger.warning("Account '\(sourceProfileUrl)' cannot be downloaded from remote server.")
            return
        }
                
        let targetUser = try await usersService.get(activityPubProfile: activityPubObject.id, on: context.db)
        guard let targetUser else {
            context.logger.warning("Cannot find local user '\(activityPubObject.id)'.")
            return
        }
        
        // Relationship is automatically approved when user disabled manual approval.
        let approved = targetUser.manuallyApprovesFollowers == false
        
        _ = try await followsService.follow(sourceId: remoteUser.requireID(),
                                            targetId: targetUser.requireID(),
                                            approved: approved,
                                            activityId: activityId,
                                            on: context)
        
        try await usersService.updateFollowCount(for: remoteUser.requireID(), on: context.db)
        try await usersService.updateFollowCount(for: targetUser.requireID(), on: context.db)
        
        // Send notification to user about follow.
        let notificationsService = context.services.notificationsService
        try await notificationsService.create(type: approved ? .follow : .followRequest,
                                              to: targetUser,
                                              by: remoteUser.requireID(),
                                              statusId: nil,
                                              mainStatusId: nil,
                                              on: context)
        
        // Save into queue information about accepted follow which have to be send to remote instance.
        if approved {
            try await self.respondAccept(requesting: remoteUser.activityPubProfile,
                                         asked: targetUser.activityPubProfile,
                                         inbox: remoteUser.userInbox,
                                         withId: remoteUser.requireID(),
                                         acceptedId: activityId,
                                         privateKey: targetUser.privateKey,
                                         on: context)
        }
    }
    
    private func accept(targetProfileUrl: String, activityPubObject: ObjectDto, on context: ExecutionContext) async throws {
        guard activityPubObject.type == .follow  else {
            throw ActivityPubError.acceptTypeNotSupported(activityPubObject.type)
        }
        
        guard let followDto = activityPubObject.object as? FollowDto else {
            throw ActivityPubError.entityCaseError(String(describing: FollowDto.self))
        }
        
        guard let sourceActorIds = followDto.actor?.actorIds() else {
            return
        }
        
        for sourceProfileUrl in sourceActorIds {
            try await self.accept(sourceProfileUrl: sourceProfileUrl, targetProfileUrl: targetProfileUrl, on: context)
        }
    }
    
    private func accept(sourceProfileUrl: String, targetProfileUrl: String, on context: ExecutionContext) async throws {
        context.logger.info("Accepting account: '\(sourceProfileUrl)' by account '\(targetProfileUrl)' (from remote server).")

        let followsService = context.services.followsService
        let usersService = context.services.usersService

        let remoteUser = try await usersService.get(activityPubProfile: targetProfileUrl, on: context.db)
        guard let remoteUser else {
            context.logger.warning("Account '\(targetProfileUrl)' cannot be found in local database.")
            return
        }
                
        let sourceUser = try await usersService.get(activityPubProfile: sourceProfileUrl, on: context.db)
        guard let sourceUser else {
            context.logger.warning("Account '\(sourceProfileUrl)' cannot be found in local database.")
            return
        }
        
        _ = try await followsService.approve(sourceId: sourceUser.requireID(), targetId: remoteUser.requireID(), on: context.db)
        try await usersService.updateFollowCount(for: remoteUser.requireID(), on: context.db)
        try await usersService.updateFollowCount(for: sourceUser.requireID(), on: context.db)
    }
    
    private func reject(targetProfileUrl: String, activityPubObject: ObjectDto, on context: ExecutionContext) async throws {
        guard activityPubObject.type == .follow  else {
            throw ActivityPubError.rejectTypeNotSupported(activityPubObject.type)
        }
        
        guard let followDto = activityPubObject.object as? FollowDto else {
            throw ActivityPubError.entityCaseError(String(describing: FollowDto.self))
        }
        
        guard let sourceActorIds = followDto.actor?.actorIds() else {
            return
        }
        
        for sourceProfileUrl in sourceActorIds {
            try await self.reject(sourceProfileUrl: sourceProfileUrl, targetProfileUrl: targetProfileUrl, on: context)
        }
    }
    
    private func reject(sourceProfileUrl: String, targetProfileUrl: String, on context: ExecutionContext) async throws {
        context.logger.info("Rejecting account: '\(sourceProfileUrl)' by account '\(targetProfileUrl)' (from remote server).")

        let followsService = context.services.followsService
        let usersService = context.services.usersService

        let remoteUser = try await usersService.get(activityPubProfile: targetProfileUrl, on: context.db)
        guard let remoteUser else {
            context.logger.warning("Account '\(targetProfileUrl)' cannot be found in local database.")
            return
        }
                
        let sourceUser = try await usersService.get(activityPubProfile: sourceProfileUrl, on: context.application.db)
        guard let sourceUser else {
            context.logger.warning("Account '\(sourceProfileUrl)' cannot be found in local database.")
            return
        }
        
        _ = try await followsService.reject(sourceId: sourceUser.requireID(), targetId: remoteUser.requireID(), on: context.db)
        try await usersService.updateFollowCount(for: remoteUser.requireID(), on: context.db)
        try await usersService.updateFollowCount(for: sourceUser.requireID(), on: context.db)
    }

    public func isDomainBlockedByInstance(actorId: String, on context: ExecutionContext) async throws -> Bool {
        let instanceBlockedDomainsService = context.services.instanceBlockedDomainsService
        
        guard let url = URL(string: actorId) else {
            return false
        }

        return try await instanceBlockedDomainsService.exists(url: url, on: context.db)
    }
    
    public func isDomainBlockedByInstance(activity: ActivityDto, on context: ExecutionContext) async throws -> Bool {
        let instanceBlockedDomainsService = context.services.instanceBlockedDomainsService

        guard let activityPubProfile = activity.actor.actorIds().first else {
            return false
        }
        
        guard let url = URL(string: activityPubProfile) else {
            return false
        }

        return try await instanceBlockedDomainsService.exists(url: url, on: context.db)
    }
    
    public func isDomainBlockedByUser(actorId: String, on context: ExecutionContext) async throws -> Bool {
        let userBlockedDomainsService = context.services.userBlockedDomainsService
        
        guard let url = URL(string: actorId) else {
            return false
        }

        return try await userBlockedDomainsService.exists(url: url, on: context.db)
    }
    
    private func respondAccept(requesting: String,
                               asked: String,
                               inbox: String?,
                               withId id: Int64,
                               acceptedId: String,
                               privateKey: String?,
                               on context: ExecutionContext) async throws {
        guard let inbox, let inboxUrl = URL(string: inbox) else {
            return
        }
        
        guard let privateKey else {
            return
        }
        
        let activityPubFollowRespondDto = ActivityPubFollowRespondDto(approved: true,
                                                                      requesting: requesting,
                                                                      asked: asked,
                                                                      inbox: inboxUrl,
                                                                      id: id,
                                                                      orginalRequestId: acceptedId,
                                                                      privateKey: privateKey)

        try await context
            .queues(.apFollowResponder)
            .dispatch(ActivityPubFollowResponderJob.self, activityPubFollowRespondDto)
    }
        
    public func downloadStatus(activityPubId: String, on context: ExecutionContext) async throws -> Status {
        let statusesService = context.services.statusesService
        let searchService = context.services.searchService

        // When we already have status in database we don't have to downlaod it.
        if let status = try await statusesService.get(activityPubId: activityPubId, on: context.db) {
            return status
        }
        
        // Download status JSON from remote server (via ActivityPub endpoints).
        context.logger.info("Downloading status from remote server: '\(activityPubId)'.")
        let noteDto = try await self.downloadRemoteStatus(activityPubId: activityPubId, on: context)
        
        // Verify once again if status not exist in database.
        if let status = try await statusesService.get(activityPubId: noteDto.url, on: context.db) {
            return status
        }

        if noteDto.attachment?.contains(where: { $0.mediaType.starts(with: "image/") }) == false {
            context.logger.warning("Object doesn't contain any image media type attachments (status: \(noteDto.id).")
            throw ActivityPubError.missingAttachments(activityPubId)
        }
        
        // Download user data to local database.
        context.logger.info("Downloading user profile from remote server: '\(noteDto.attributedTo)'.")
        let remoteUser = try await searchService.downloadRemoteUser(activityPubProfile: noteDto.attributedTo, on: context)

        guard let remoteUser else {
            await context.logger.store("Account '\(noteDto.attributedTo)' cannot be downloaded from remote server.", nil, on: context.application)
            throw ActivityPubError.actorNotDownloaded(noteDto.attributedTo)
        }
        
        // Create status in database.
        context.logger.info("Creating status in local database: '\(activityPubId)'.")
        let status = try await statusesService.create(basedOn: noteDto, userId: remoteUser.requireID(), on: context)
        
        // Recalculate numer of user statuses.
        try await statusesService.updateStatusCount(for: remoteUser.requireID(), on: context.db)
        
        return status
    }
    
    private func downloadRemoteStatus(activityPubId: String, on context: ExecutionContext) async throws -> NoteDto {
        do {
            guard let noteUrl = URL(string: activityPubId) else {
                await context.logger.store("Invalid URL to note: '\(activityPubId)'.", nil, on: context.application)
                throw ActivityPubError.invalidNoteUrl(activityPubId)
            }
            
            let usersService = context.services.usersService
            guard let defaultSystemUser = try await usersService.getDefaultSystemUser(on: context.db) else {
                throw ActivityPubError.missingInstanceAdminAccount
            }
            
            guard let privateKey = defaultSystemUser.privateKey else {
                throw ActivityPubError.missingInstanceAdminPrivateKey
            }

            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: noteUrl.host)
            return try await activityPubClient.note(url: noteUrl, activityPubProfile: defaultSystemUser.activityPubProfile)
        } catch {
            await context.logger.store("Error during download status: '\(activityPubId)'.", error, on: context.application)
            throw ActivityPubError.statusHasNotBeenDownloaded(activityPubId)
        }
    }
    
    private func isRemoteUserFollowedByAnyone(activityPubProfile: String, on context: ExecutionContext) async throws -> Bool {
        let usersService = context.services.usersService
        guard let user = try await usersService.get(activityPubProfile: activityPubProfile, on: context.db) else {
            return false
        }
        
        let followers = try await Follow.query(on: context.db)
            .filter(\.$target.$id == user.requireID())
            .filter(\.$approved == true)
            .join(User.self, on: \Follow.$source.$id == \User.$id)
            .filter(User.self, \.$isLocal == true)
            .count()

        return followers > 0
    }
    
    private func isParentStatusInDatabase(replyToActivityPubId: String?, on context: ExecutionContext) async throws -> Bool {
        guard let replyToActivityPubId else {
            return false
        }
        
        let statusesService = context.services.statusesService
        guard let _ = try await statusesService.get(activityPubId: replyToActivityPubId, on: context.db) else {
            return false
        }
        
        return true
    }
    
    private func isLocalObjectOnTheList(objects: [ObjectDto], baseAddress: String) -> Bool {
        return objects.contains { $0.id.starts(with: "\(baseAddress)/") }
    }
}
