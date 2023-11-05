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
    func delete(on context: QueueContext, activity: ActivityDto) throws
    func create(on context: QueueContext, activity: ActivityDto) async throws
    func follow(on context: QueueContext, activity: ActivityDto) async throws
    func accept(on context: QueueContext, activity: ActivityDto) async throws
    func reject(on context: QueueContext, activity: ActivityDto) async throws
    func undo(on context: QueueContext, activity: ActivityDto) async throws
    func announce(on context: QueueContext, activity: ActivityDto) async throws
}

final class ActivityPubService: ActivityPubServiceType {
    public func delete(on context: QueueContext, activity: ActivityDto) throws {
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
                try await statusesService.createOnLocalTimeline(statusId: statusFromDatabase.requireID(),
                                                                followersOf: user.requireID(),
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
            let mainStatus = try await self.downloadStatus(on: context, activityPubUrl: object.id)
                        
            // Create reblog status.
            let reblogStatus = try Status(isLocal: false,
                                    userId: remoteUser.requireID(),
                                    note: nil,
                                    baseAddress: baseAddress,
                                    userName: remoteUser.userName,
                                    application: nil,
                                    visibility: .public,
                                    reblogId: mainStatus.requireID())
            
            try await reblogStatus.create(on: context.application.db)
            try await statusesService.updateReblogsCount(for: mainStatus.requireID(), on: context.application.db)
            
            // Add new reblog status to user's timelines.
            context.logger.info("Connecting status '\(reblogStatus.stringId() ?? "")' to followers of '\(remoteUser.stringId() ?? "")'.")
            try await statusesService.createOnLocalTimeline(statusId: reblogStatus.requireID(),
                                                            followersOf: remoteUser.requireID(),
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
    
    private func downloadStatus(on context: QueueContext, activityPubUrl: String) async throws -> Status {
        let statusesService = context.application.services.statusesService
        let searchService = context.application.services.searchService

        // When we already have status in database we don't have to downlaod it.
        if let status = try await statusesService.get(on: context.application.db, activityPubUrl: activityPubUrl) {
            return status
        }
        
        // Download status JSON from remote server (via ActivityPub endpoints).
        context.logger.info("Downloading status from remote server: '\(activityPubUrl)'.")
        let noteDto = try await self.downloadRemoteStatus(on: context, activityPubUrl: activityPubUrl)

        if noteDto.attachment?.contains(where: { $0.mediaType.starts(with: "image/") }) == false {
            context.logger.error("Object doesn't contain any image media type attachments (status: \(noteDto.id).")
            throw ActivityPubError.missingAttachments(activityPubUrl)
        }
        
        // Download user data to local database.
        context.logger.info("Downloading user profile from remote server: '\(noteDto.attributedTo)'.")
        let remoteUser = try await searchService.downloadRemoteUser(profileUrl: noteDto.attributedTo, on: context)

        guard let remoteUser else {
            context.logger.error("Account '\(noteDto.attributedTo)' cannot be downloaded from remote server.")
            throw ActivityPubError.actorNotDownloaded(noteDto.attributedTo)
        }
        
        // Create status in database.
        context.logger.info("Creating status in local database: '\(activityPubUrl)'.")
        let status = try await statusesService.create(basedOn: noteDto, userId: remoteUser.requireID(), on: context)
        return status
    }
    
    private func downloadRemoteStatus(on context: QueueContext, activityPubUrl: String) async throws -> NoteDto {
        do {
            guard let noteUrl = URL(string: activityPubUrl) else {
                context.logger.error("Invalid URL to note: '\(activityPubUrl)'.")
                throw ActivityPubError.invalidNoteUrl(activityPubUrl)
            }
            
            let activityPubClient = ActivityPubClient()
            return try await activityPubClient.note(url: noteUrl)
        } catch {
            context.logger.error("Error during download status: '\(activityPubUrl)'. Error: \(error).")
            throw ActivityPubError.statusHasNotBeenDownloaded(activityPubUrl)
        }
    }
}
