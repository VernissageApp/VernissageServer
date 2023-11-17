//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
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

/// Service responsible for consuming requests retrieved on Activity Pub controllers from remote instances.
protocol ActivityPubServiceType {
    func delete(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) async throws
    func create(on context: QueueContext, activity: ActivityDto) async throws
    func follow(on context: QueueContext, activity: ActivityDto) async throws
    func accept(on context: QueueContext, activity: ActivityDto) async throws
    func reject(on context: QueueContext, activity: ActivityDto) async throws
    func undo(on context: QueueContext, activity: ActivityDto) async throws
    func announce(on context: QueueContext, activity: ActivityDto) async throws
}

final class ActivityPubService: ActivityPubServiceType {

    public func delete(on context: QueueContext, activityPubRequest: ActivityPubRequestDto) async throws {
        let statusesService = context.application.services.statusesService
        let usersService = context.application.services.usersService
        let activityPubSignatureService = context.application.services.activityPubSignatureService
        
        let objects = activityPubRequest.activity.object.objects()
        for object in objects {
            switch object.type {
            case .some(.note):
                context.logger.info("Deleting status: '\(object.id)'.")
                guard let statusToDelete = try await statusesService.get(on: context.application.db, activityPubId: object.id) else {
                    context.logger.info("Deleting status: '\(object.id)'. Status not exists in local database.")
                    continue
                }
                
                guard statusToDelete.isLocal == false else {
                    context.logger.info("Deleting status: '\(object.id)'. Cannot deletee local status from ActivityPub request.")
                    continue
                }
                
                // Validate signature (also with users downloaded from remote server).
                try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: activityPubRequest)
                
                // Signature verified, we can delete status.
                try await statusesService.delete(id: statusToDelete.requireID(), on: context.application.db)
                context.logger.info("Deleting status: '\(object.id)'. Status deleted from local database successfully.")
            case .none, .some(.profile):
                context.logger.info("Deleting user: '\(object.id)'.")
                guard let userToDelete = try await usersService.get(on: context.application.db, activityPubProfile: object.id) else {
                    context.logger.info("Deleting user: '\(object.id)'. User not exists in local database.")
                    continue
                }
                
                guard userToDelete.isLocal == false else {
                    context.logger.info("Deleting user: '\(object.id)'. Cannot deletee local user from ActivityPub request.")
                    continue
                }
                
                // Validate signature with local database only (user has been alredy removed from remote).
                try await activityPubSignatureService.validateLocalSignature(on: context, activityPubRequest: activityPubRequest)

                // Signature verified, we can delete user.
                try await usersService.delete(user: userToDelete, on: context.application.db)
                context.logger.info("Deleting user: '\(object.id)'. User deleted from local database successfully.")
            default:
                context.logger.warning("Deleting object type: '\(object.type?.rawValue ?? "<unknown>")' is not supported yet.")
            }
        }
    }
    
    public func create(on context: QueueContext, activity: ActivityDto) async throws {
        let statusesService = context.application.services.statusesService
        let usersService = context.application.services.usersService
        
        let objects = activity.object.objects()
        for object in objects {
            switch object.type {
            case .note:
                guard let noteDto = object.object as? NoteDto else {
                    context.logger.warning("Cannot cast note type object to NoteDto (activity: \(activity.id).")
                    continue
                }
                
                guard let actor = activity.actor.actorIds().first,
                      let user = try await usersService.get(on: context.application.db, activityPubProfile: actor) else {
                    context.logger.warning("User '\(activity.actor.actorIds().first ?? "")' cannot found in the local database.")
                    continue
                }
                
                if noteDto.attachment?.contains(where: { $0.mediaType.starts(with: "image/") }) == false {
                    context.logger.warning("Object doesn't contain any image media type attachments (activity: \(activity.id).")
                    continue
                }
                
                // Create status into database.
                let statusFromDatabase = try await statusesService.create(basedOn: noteDto, userId: user.requireID(), on: context)
                
                // Add new status to user's timelines.
                try await statusesService.createOnLocalTimeline(followersOf: user.requireID(),
                                                                statusId: statusFromDatabase.requireID(),
                                                                on: context)
            default:
                context.logger.warning("Object type: '\(object.type?.rawValue ?? "<unknown>")' is not supported yet.")
            }
        }
    }
    
    public func follow(on context: QueueContext, activity: ActivityDto) async throws {
        let actorIds = activity.actor.actorIds()
        for actorId in actorIds {
            let domainIsBlockedByInstance = try await self.isDomainBlockedByInstance(on: context, actorId: actorId)
            guard domainIsBlockedByInstance == false else {
                context.logger.warning("Actor: '\(actorId)' is blocked by instance domain blocks.")
                continue
            }
            
            let objects = activity.object.objects()
            for object in objects {
                let domainIsBlockedByUser = try await self.isDomainBlockedByUser(on: context, actorId: object.id)
                guard domainIsBlockedByUser == false else {
                    context.logger.warning("Actor: '\(actorId)' is blocked by user (\(object.id)) domain blocks.")
                    continue
                }
                
                try await self.follow(sourceProfileUrl: actorId, activityPubObject: object, on: context, activityId: activity.id)
            }
        }
    }
    
    public func accept(on context: QueueContext, activity: ActivityDto) async throws {
        let actorIds = activity.actor.actorIds()
        for targetActorId in actorIds {
            let objects = activity.object.objects()
            for object in objects {
                try await self.accept(targetProfileUrl: targetActorId, activityPubObject: object, on: context)
            }
        }
    }

    public func reject(on context: QueueContext, activity: ActivityDto) async throws {
        let actorIds = activity.actor.actorIds()
        for targetActorId in actorIds {
            let objects = activity.object.objects()
            for object in objects {
                try await self.reject(targetProfileUrl: targetActorId, activityPubObject: object, on: context)
            }
        }
    }
    
    func undo(on context: QueueContext, activity: ActivityDto) async throws {
        let objects = activity.object.objects()
        for object in objects {
            switch object.type {
            case .follow:
                for sourceActorId in activity.actor.actorIds() {
                    try await self.unfollow(sourceActorId: sourceActorId, activityPubObject: object, on: context)
                }
            default:
                context.logger.warning("Undo of '\(object.type?.rawValue ?? "<unknown>")' action is not supported")
            }
        }
    }
    
    public func announce(on context: QueueContext, activity: ActivityDto) async throws {
        let statusesService = context.application.services.statusesService
        let searchService = context.application.services.searchService
        
        // Download user data (who reblogged status) to local database.
        guard let actorActivityPubId = activity.actor.actorIds().first,
              let remoteUser = try await searchService.downloadRemoteUser(profileUrl: actorActivityPubId, on: context) else {
            context.logger.warning("User '\(activity.actor.actorIds().first ?? "")' cannot found in the local database.")
            return
        }
        
        let appplicationSettings = context.application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        
        let objects = activity.object.objects()
        for object in objects {
            // Create main status in local database.
            let mainStatus = try await self.downloadStatus(on: context, activityPubId: object.id)
                        
            // Create reblog status.
            let reblogStatus = try Status(isLocal: false,
                                    userId: remoteUser.requireID(),
                                    note: nil,
                                    baseAddress: baseAddress,
                                    userName: remoteUser.userName,
                                    application: nil,
                                    categoryId: nil,
                                    visibility: .public,
                                    reblogId: mainStatus.requireID())
            
            try await reblogStatus.create(on: context.application.db)
            try await statusesService.updateReblogsCount(for: mainStatus.requireID(), on: context.application.db)
            
            // Add new reblog status to user's timelines.
            context.logger.info("Connecting status '\(reblogStatus.stringId() ?? "")' to followers of '\(remoteUser.stringId() ?? "")'.")
            try await statusesService.createOnLocalTimeline(followersOf: remoteUser.requireID(),
                                                            statusId: reblogStatus.requireID(),
                                                            on: context)
        }
    }
    
    private func unfollow(sourceActorId: String, activityPubObject: ObjectDto, on context: QueueContext) async throws {
        guard let followDto = activityPubObject.object as? FollowDto,
              let objects = followDto.object?.objects() else {
            return
        }
        
        for object in objects {
            try await self.unfollow(sourceProfileUrl: sourceActorId, activityPubObject: object, on: context)
        }
    }
    
    private func unfollow(sourceProfileUrl: String, activityPubObject: ObjectDto, on context: QueueContext) async throws {        
        context.logger.info("Unfollowing account: '\(activityPubObject.id)' by account '\(sourceProfileUrl)' (from remote server).")

        let followsService = context.application.services.followsService
        let usersService = context.application.services.usersService
        
        let sourceUser = try await usersService.get(on: context.application.db, activityPubProfile: sourceProfileUrl)
        guard let sourceUser else {
            context.logger.warning("Cannot find user '\(sourceProfileUrl)' in local database.")
            return
        }
        
        let targetUser = try await usersService.get(on: context.application.db, activityPubProfile: activityPubObject.id)
        guard let targetUser else {
            context.logger.warning("Cannot find user '\(activityPubObject.id)' in local database.")
            return
        }
        
        _ = try await followsService.unfollow(on: context.application.db, sourceId: sourceUser.requireID(), targetId: targetUser.requireID())
        try await usersService.updateFollowCount(on: context.application.db, for: sourceUser.requireID())
        try await usersService.updateFollowCount(on: context.application.db, for: targetUser.requireID())
    }
    
    private func follow(sourceProfileUrl: String, activityPubObject: ObjectDto, on context: QueueContext, activityId: String) async throws {        
        context.logger.info("Following account: '\(activityPubObject.id)' by account '\(sourceProfileUrl)' (from remote server).")

        let searchService = context.application.services.searchService
        let followsService = context.application.services.followsService
        let usersService = context.application.services.usersService

        // Download profile from remote server.
        context.logger.info("Downloading account \(sourceProfileUrl) from remote server.")

        let remoteUser = try await searchService.downloadRemoteUser(profileUrl: sourceProfileUrl, on: context)
        guard let remoteUser else {
            context.logger.warning("Account '\(sourceProfileUrl)' cannot be downloaded from remote server.")
            return
        }
                
        let targetUser = try await usersService.get(on: context.application.db, activityPubProfile: activityPubObject.id)
        guard let targetUser else {
            context.logger.warning("Cannot find local user '\(activityPubObject.id)'.")
            return
        }
        
        // Relationship is automatically approved when user disabled manual approval.
        let approved = targetUser.manuallyApprovesFollowers == false
        
        _ = try await followsService.follow(on: context.application.db,
                                            sourceId: remoteUser.requireID(),
                                            targetId: targetUser.requireID(),
                                            approved: approved,
                                            activityId: activityId)
        
        try await usersService.updateFollowCount(on: context.application.db, for: remoteUser.requireID())
        try await usersService.updateFollowCount(on: context.application.db, for: targetUser.requireID())
        
        // Send notification to user about follow.
        let notificationsService = context.application.services.notificationsService
        try await notificationsService.create(type: approved ? .follow : .followRequest,
                                              to: targetUser,
                                              by: remoteUser.requireID(),
                                              statusId: nil,
                                              on: context.application.db)
        
        // Save into queue information about accepted follow which have to be send to remote instance.
        if approved {
            try await self.respondAccept(on: context,
                                         requesting: remoteUser.activityPubProfile,
                                         asked: targetUser.activityPubProfile,
                                         inbox: remoteUser.userInbox,
                                         withId: remoteUser.requireID(),
                                         acceptedId: activityId,
                                         privateKey: targetUser.privateKey)
        }
    }
    
    private func accept(targetProfileUrl: String, activityPubObject: ObjectDto, on context: QueueContext) async throws {
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
    
    private func accept(sourceProfileUrl: String, targetProfileUrl: String, on context: QueueContext) async throws {
        context.logger.info("Accepting account: '\(sourceProfileUrl)' by account '\(targetProfileUrl)' (from remote server).")

        let followsService = context.application.services.followsService
        let usersService = context.application.services.usersService

        let remoteUser = try await usersService.get(on: context.application.db, activityPubProfile: targetProfileUrl)
        guard let remoteUser else {
            context.logger.warning("Account '\(targetProfileUrl)' cannot be found in local database.")
            return
        }
                
        let sourceUser = try await usersService.get(on: context.application.db, activityPubProfile: sourceProfileUrl)
        guard let sourceUser else {
            context.logger.warning("Account '\(sourceProfileUrl)' cannot be found in local database.")
            return
        }
        
        _ = try await followsService.approve(on: context.application.db, sourceId: sourceUser.requireID(), targetId: remoteUser.requireID())
        try await usersService.updateFollowCount(on: context.application.db, for: remoteUser.requireID())
        try await usersService.updateFollowCount(on: context.application.db, for: sourceUser.requireID())
    }
    
    private func reject(targetProfileUrl: String, activityPubObject: ObjectDto, on context: QueueContext) async throws {
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
    
    private func reject(sourceProfileUrl: String, targetProfileUrl: String, on context: QueueContext) async throws {
        context.logger.info("Rejecting account: '\(sourceProfileUrl)' by account '\(targetProfileUrl)' (from remote server).")

        let followsService = context.application.services.followsService
        let usersService = context.application.services.usersService

        let remoteUser = try await usersService.get(on: context.application.db, activityPubProfile: targetProfileUrl)
        guard let remoteUser else {
            context.logger.warning("Account '\(targetProfileUrl)' cannot be found in local database.")
            return
        }
                
        let sourceUser = try await usersService.get(on: context.application.db, activityPubProfile: sourceProfileUrl)
        guard let sourceUser else {
            context.logger.warning("Account '\(sourceProfileUrl)' cannot be found in local database.")
            return
        }
        
        _ = try await followsService.reject(on: context.application.db, sourceId: sourceUser.requireID(), targetId: remoteUser.requireID())
        try await usersService.updateFollowCount(on: context.application.db, for: remoteUser.requireID())
        try await usersService.updateFollowCount(on: context.application.db, for: sourceUser.requireID())
    }

    public func isDomainBlockedByInstance(on context: QueueContext, actorId: String) async throws -> Bool {
        let instanceBlockedDomainsService = context.application.services.instanceBlockedDomainsService
        
        guard let url = URL(string: actorId) else {
            return false
        }

        return try await instanceBlockedDomainsService.exists(on: context.application.db, url: url)
    }
    
    public func isDomainBlockedByUser(on context: QueueContext, actorId: String) async throws -> Bool {
        let userBlockedDomainsService = context.application.services.userBlockedDomainsService
        
        guard let url = URL(string: actorId) else {
            return false
        }

        return try await userBlockedDomainsService.exists(on: context.application.db, url: url)
    }
    
    private func respondAccept(on context: QueueContext,
                               requesting: String,
                               asked: String,
                               inbox: String?,
                               withId id: Int64,
                               acceptedId: String,
                               privateKey: String?) async throws {
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
    
    private func downloadStatus(on context: QueueContext, activityPubId: String) async throws -> Status {
        let statusesService = context.application.services.statusesService
        let searchService = context.application.services.searchService

        // When we already have status in database we don't have to downlaod it.
        if let status = try await statusesService.get(on: context.application.db, activityPubId: activityPubId) {
            return status
        }
        
        // Download status JSON from remote server (via ActivityPub endpoints).
        context.logger.info("Downloading status from remote server: '\(activityPubId)'.")
        let noteDto = try await self.downloadRemoteStatus(on: context, activityPubId: activityPubId)

        if noteDto.attachment?.contains(where: { $0.mediaType.starts(with: "image/") }) == false {
            context.logger.error("Object doesn't contain any image media type attachments (status: \(noteDto.id).")
            throw ActivityPubError.missingAttachments(activityPubId)
        }
        
        // Download user data to local database.
        context.logger.info("Downloading user profile from remote server: '\(noteDto.attributedTo)'.")
        let remoteUser = try await searchService.downloadRemoteUser(profileUrl: noteDto.attributedTo, on: context)

        guard let remoteUser else {
            context.logger.error("Account '\(noteDto.attributedTo)' cannot be downloaded from remote server.")
            throw ActivityPubError.actorNotDownloaded(noteDto.attributedTo)
        }
        
        // Create status in database.
        context.logger.info("Creating status in local database: '\(activityPubId)'.")
        let status = try await statusesService.create(basedOn: noteDto, userId: remoteUser.requireID(), on: context)
        return status
    }
    
    private func downloadRemoteStatus(on context: QueueContext, activityPubId: String) async throws -> NoteDto {
        do {
            guard let noteUrl = URL(string: activityPubId) else {
                context.logger.error("Invalid URL to note: '\(activityPubId)'.")
                throw ActivityPubError.invalidNoteUrl(activityPubId)
            }
            
            let activityPubClient = ActivityPubClient()
            return try await activityPubClient.note(url: noteUrl)
        } catch {
            context.logger.error("Error during download status: '\(activityPubId)'. Error: \(error).")
            throw ActivityPubError.statusHasNotBeenDownloaded(activityPubId)
        }
    }
}
