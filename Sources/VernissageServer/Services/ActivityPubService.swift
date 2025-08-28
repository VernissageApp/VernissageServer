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
    /// Deletes content based on the given ActivityPub request.
    ///
    /// Processes the deletion of statuses or users specified in the ActivityPub request.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the activity to delete.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if deletion fails or validation fails during processing.
    func delete(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Creates content based on the given ActivityPub request.
    ///
    /// Handles creation of new statuses or other supported objects from the ActivityPub request.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the activity to create.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if creation or validations fail.
    func create(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Updates existing content based on the given ActivityPub request.
    ///
    /// Processes updates to statuses or objects contained in the ActivityPub request.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the activity to update.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if update fails or the target object is not found.
    func update(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Processes a follow request from the ActivityPub request.
    ///
    /// Handles follow activities where a remote user follows a local user.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the follow activity.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the follow operation fails.
    func follow(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Accepts a follow request based on the ActivityPub request.
    ///
    /// Handles approval of a follow request initiated by a remote user.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the accept activity.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if acceptance fails or the activity type is unsupported.
    func accept(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Rejects a follow request based on the ActivityPub request.
    ///
    /// Handles rejection of a follow request initiated by a remote user.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the reject activity.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if rejection fails or the activity type is unsupported.
    func reject(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Undoes a previous action specified in the ActivityPub request.
    ///
    /// Handles undoing actions such as unfollow, unannounce (unboost), or unlike.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the undo activity.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if undo operation fails or the action is unsupported.
    func undo(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Processes a like activity based on the ActivityPub request.
    ///
    /// Handles liking of statuses by remote users and updates related data.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the like activity.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if liking fails or related data cannot be processed.
    func like(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Processes an announce (boost/reblog) activity based on the ActivityPub request.
    ///
    /// Handles boosting or reblogging of statuses by remote users.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the announce activity.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the announce operation fails.
    func announce(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Creates and distributes a status based on the given ActivityPub status event.
    ///
    /// Processes the status creation and sends it to remote shared inboxes, handling network communication and activity event lifecycle.
    ///
    /// - Parameters:
    ///   - statusActivityPubEvent: The event describing the status creation and its distribution targets.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the status could not be sent, or if validation or processing fails.
    func create(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws
    
    /// Updates status information based on an ActivityPub status event.
    ///
    /// Processes and sends updates for a status to remote shared inboxes, handling network communication and status history.
    ///
    /// - Parameters:
    ///   - statusActivityPubEvent: The event describing the status update and its distribution targets.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the update could not be sent, history cannot be retrieved, or validation fails during processing.
    func update(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws
        
    /// Creates and distributes a like (favourite) activity based on the given status event.
    ///
    /// Processes the creation and remote distribution of a like/favourite for a status, handling network communication and event lifecycle.
    ///
    /// - Parameters:
    ///   - statusActivityPubEvent: The event describing the like action and its distribution targets.
    ///   - statusFavouriteId: The identifier of the status favourite (like) to be sent.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the like cannot be sent, or if validation or processing fails.
    func like(statusActivityPubEvent: StatusActivityPubEvent, statusFavouriteId: String?, on context: ExecutionContext) async throws

    /// Creates and distributes an unlike (unfavourite) activity based on the given status event.
    ///
    /// Processes the removal and remote distribution of a like/favourite for a status, handling network communication and event lifecycle.
    ///
    /// - Parameters:
    ///   - statusActivityPubEvent: The event describing the unlike action and its distribution targets.
    ///   - statusFavouriteId: The identifier of the status favourite (like) to be removed.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the unlike cannot be sent, or if validation or processing fails.
    func unlike(statusActivityPubEvent: StatusActivityPubEvent, statusFavouriteId: String?, on context: ExecutionContext) async throws
    
    /// Creates and distributes an announce (boost/reblog) activity based on the given status event.
    ///
    /// Processes the creation and remote distribution of an announce/boost for a status, handling network communication and event lifecycle.
    ///
    /// - Parameters:
    ///   - statusActivityPubEvent: The event describing the announce action and its distribution targets.
    ///   - activityPubReblog: The data describing the reblog/boost, or `nil` if not available.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the announce cannot be sent, or if validation or processing fails.
    func announce(statusActivityPubEvent: StatusActivityPubEvent, activityPubReblog: ActivityPubReblogDto?, on context: ExecutionContext) async throws
    
    /// Creates and distributes an unannounce (undo boost/unreblog) activity based on the given status event.
    ///
    /// Processes the removal and remote distribution of a previous announce/boost for a status, handling network communication and event lifecycle.
    ///
    /// - Parameters:
    ///   - statusActivityPubEvent: The event describing the unannounce action and its distribution targets.
    ///   - activityPubUnreblog: The data describing the unboost/unreblog, or `nil` if not available.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the unannounce cannot be sent, or if validation or processing fails.
    func unannounce(statusActivityPubEvent: StatusActivityPubEvent, activityPubUnreblog: ActivityPubUnreblogDto?, on context: ExecutionContext) async throws
    
    /// Checks if the domain of the actor ID is blocked by the local instance.
    ///
    /// - Parameters:
    ///   - actorId: The ActivityPub actor ID (URL) to check.
    ///   - context: The execution context providing services and database access.
    /// - Returns: Returns `true` if the domain is blocked, otherwise `false`.
    /// - Throws: Throws an error if the check fails.
    func isDomainBlockedByInstance(actorId: String, on context: ExecutionContext) async throws -> Bool

    /// Checks if the domain of the actor in the given activity is blocked by the local instance.
    ///
    /// - Parameters:
    ///   - activity: The ActivityPub activity DTO to check.
    ///   - context: The execution context providing services and database access.
    /// - Returns: Returns `true` if the domain is blocked, otherwise `false`.
    /// - Throws: Throws an error if the check fails.
    func isDomainBlockedByInstance(activity: ActivityDto, on context: ExecutionContext) async throws -> Bool

    /// Checks if the domain of the actor ID is blocked by the user.
    ///
    /// - Parameters:
    ///   - actorId: The ActivityPub actor ID (URL) to check.
    ///   - context: The execution context providing services and database access.
    /// - Returns: Returns `true` if the domain is blocked by the user, otherwise `false`.
    /// - Throws: Throws an error if the check fails.
    func isDomainBlockedByUser(actorId: String, on context: ExecutionContext) async throws -> Bool

    /// Downloads a status by its ActivityPub ID.
    ///
    /// If the status does not exist locally, attempts to download and store it.
    ///
    /// - Parameters:
    ///   - activityPubId: The ActivityPub ID (URL) of the status to download.
    ///   - context: The execution context providing services and database access.
    /// - Returns: The downloaded or existing local `Status` object.
    /// - Throws: Throws an error if the status cannot be downloaded or processed.
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
    
    public func update(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let statusesService = context.services.statusesService
        let activity = activityPubRequest.activity
        
        let objects = activity.object.objects()
        for object in objects {
            switch object.type {
            case .note:
                guard let noteDto = object.object as? NoteDto else {
                    context.logger.warning("Cannot cast note type object to NoteDto (activity: \(activity.id).")
                    continue
                }

                guard let orginalStatus = try await statusesService.get(activityPubId: noteDto.id, on: context.db) else {
                    context.logger.warning("Cannot update status because status doesn't exist in local database (activity: \(noteDto.id)).")
                    continue
                }
                
                guard let statusFromDatabase = try await statusesService.get(id: orginalStatus.requireID(), on: context.db) else {
                    context.logger.warning("Cannot update status because status doesn't exist in local database (id: \(orginalStatus.stringId() ?? "")).")
                    continue
                }

                // Update status into database.
                _ = try await statusesService.update(status: statusFromDatabase, basedOn: noteDto, on: context)
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
                context.logger.info("Status '\(object.id)' not exists in local database. Thus cannot be favourited by user '\(remoteUserId)'.")
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
        guard let announceDto = activityPubObject.object as? LikeDto,
              let objects = announceDto.object?.objects() else {
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
        let applicationSettings = context.application.settings.cached
        let baseAddress = applicationSettings?.baseAddress ?? ""

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
    
    public func create(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        let statusesService = context.services.statusesService
        let status = statusActivityPubEvent.status
        
        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }
        
        // Get information about reply status.
        let replyToStatus: Status? = if let replyToStatusId = status.$replyToStatus.id {
            try await statusesService.get(id: replyToStatusId, on: context.application.db)
        } else {
            nil
        }
        
        // Prepare note DTO object.
        let noteDto = try await statusesService.note(basedOn: status, replyToStatus: replyToStatus, on: context)
        
        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter { $0.isSuccess == nil }
        
        // Send created note to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            // Mark start date of the event item.
            eventItem.startAt = Date()
            try await statusActivityPubEvent.save(on: context.db)

            // Translate string into URL.
            guard let sharedInboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Status: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."

                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }

            // Prepare ActivityPub client.
            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending create status: '\(status.stringId() ?? "")' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                // Send status create via network to remote server.
                try await activityPubClient.create(note: noteDto,
                                                   activityPubProfile: noteDto.attributedTo,
                                                   activityPubReplyProfile: replyToStatus?.user.activityPubProfile,
                                                   on: sharedInboxUrl)
                
                // Mark event item as finished successfully.
                try? await eventItem.success(on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                context.logger.warning("Sending create status to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }
        
        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }
    
    public func update(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        let statusesService = context.services.statusesService
        let status = statusActivityPubEvent.status
        
        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }
        
        // Status history item is required for sending ActivityPub update status request.
        guard let statusHistory = try await self.getStatusHistory(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }
        
        // Get information about reply status.
        let replyToStatus: Status? = if let replyToStatusId = status.$replyToStatus.id {
            try await statusesService.get(id: replyToStatusId, on: context.application.db)
        } else {
            nil
        }
        
        // Prepare note DTO object.
        let noteDto = try await statusesService.note(basedOn: status, replyToStatus: replyToStatus, on: context)

        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter { $0.isSuccess == nil }

        // Send updated note to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            try await eventItem.start(on: context)

            // Translate string into URL.
            guard let sharedInboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Status update: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."
                
                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }

            // Prepare ActivityPub client.
            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending update status: '\(status.stringId() ?? "")' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                // Send status update via network to remote server.
                try await activityPubClient.update(historyId: statusHistory.stringId() ?? "",
                                                   published: status.updatedAt ?? Date(),
                                                   note: noteDto,
                                                   activityPubProfile: noteDto.attributedTo,
                                                   activityPubReplyProfile: replyToStatus?.user.activityPubProfile,
                                                   on: sharedInboxUrl)
                
                // Mark event item as finished successfully.
                try? await eventItem.success(on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                context.logger.warning("Sending update status to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }
        
        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }
    
    public func like(statusActivityPubEvent: StatusActivityPubEvent, statusFavouriteId: String?, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }
        
        let status = statusActivityPubEvent.status
        let user = statusActivityPubEvent.user
        
        guard let statusFavouriteId else {
            let errorMessage = "Status favourite: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing status favourite id."
            
            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return
        }
        
        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter { $0.isSuccess == nil }

        // Send updated note to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            try await eventItem.start(on: context)
            
            // Translate string into URL.
            guard let sharedInboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Favourite: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."
                
                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }
            
            // Prepare ActivityPub client.
            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending favourite: '\(statusFavouriteId)' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                // Send status favourite via network to remote server.
                try await activityPubClient.like(statusFavouriteId: statusFavouriteId,
                                                 activityPubStatusId: status.activityPubId,
                                                 activityPubProfile: user.activityPubProfile,
                                                 on: sharedInboxUrl)
                
                // Mark event item as finished successfully.
                try? await eventItem.success(on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                context.logger.warning("Sending favourite to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }
        
        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }
    
    public func unlike(statusActivityPubEvent: StatusActivityPubEvent, statusFavouriteId: String?, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }
        
        let status = statusActivityPubEvent.status
        let user = statusActivityPubEvent.user
        
        guard let statusFavouriteId else {
            let errorMessage = "Status unfavourite: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing status favourite id."
            
            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return
        }
        
        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter { $0.isSuccess == nil }

        // Send updated note to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            try await eventItem.start(on: context)
            
            // Translate string into URL.
            guard let sharedInboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Unfavourite: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."
                
                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }
            
            // Prepare ActivityPub client.
            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending unfavourite: '\(statusFavouriteId)' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                // Send status unfavourite via network to remote server.
                try await activityPubClient.unlike(statusFavouriteId: statusFavouriteId,
                                                   activityPubStatusId: status.activityPubId,
                                                   activityPubProfile: user.activityPubProfile,
                                                   on: sharedInboxUrl)
                
                // Mark event item as finished successfully.
                try? await eventItem.success(on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                context.logger.warning("Sending unfavourite to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }
        
        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }
    
    public func announce(statusActivityPubEvent: StatusActivityPubEvent, activityPubReblog: ActivityPubReblogDto?, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }
        
        let status = statusActivityPubEvent.status
        
        guard let activityPubReblog else {
            let errorMessage = "Status announce: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing announce data."
            
            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return
        }
        
        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter { $0.isSuccess == nil }

        // Send updated note to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            try await eventItem.start(on: context)
            
            // Translate string into URL.
            guard let sharedInboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Announce: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."
                
                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }
            
            // Prepare ActivityPub client.
            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending announce: '\(status.stringId() ?? "")' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                // Send status announce via network to remote server.
                try await activityPubClient.announce(activityPubStatusId: activityPubReblog.activityPubStatusId,
                                                     activityPubProfile: activityPubReblog.activityPubProfile,
                                                     published: activityPubReblog.published,
                                                     activityPubReblogProfile: activityPubReblog.activityPubReblogProfile,
                                                     activityPubReblogStatusId: activityPubReblog.activityPubReblogStatusId,
                                                     on: sharedInboxUrl)
                
                // Mark event item as finished successfully.
                try? await eventItem.success(on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                context.logger.warning("Sending announce to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }
        
        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }
    
    public func unannounce(statusActivityPubEvent: StatusActivityPubEvent, activityPubUnreblog: ActivityPubUnreblogDto?, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }
        
        let status = statusActivityPubEvent.status
        
        guard let activityPubUnreblog else {
            let errorMessage = "Status unannounce: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing unannounce data."
            
            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return
        }
        
        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter { $0.isSuccess == nil }

        // Send updated note to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            try await eventItem.start(on: context)
            
            // Translate string into URL.
            guard let sharedInboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Unannounce: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."
                
                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }
            
            // Prepare ActivityPub client.
            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending unannounce: '\(status.stringId() ?? "")' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)
            
            do {
                // Send status announce via network to remote server.
                try await activityPubClient.unannounce(activityPubStatusId: activityPubUnreblog.activityPubStatusId,
                                                       activityPubProfile: activityPubUnreblog.activityPubProfile,
                                                       published: activityPubUnreblog.published,
                                                       activityPubReblogProfile: activityPubUnreblog.activityPubReblogProfile,
                                                       activityPubReblogStatusId: activityPubUnreblog.activityPubReblogStatusId,
                                                       on: sharedInboxUrl)
                
                // Mark event item as finished successfully.
                try? await eventItem.success(on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                context.logger.warning("Sending unannounce to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }
        
        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }
    
    private func getPrivateKey(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws -> String? {
        let user = statusActivityPubEvent.user
        let status = statusActivityPubEvent.status

        guard let privateKey = try await User.query(on: context.application.db).filter(\.$id == user.requireID()).first()?.privateKey else {
            let errorMessage = "Status event: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing private key for user '\(status.user.stringId() ?? "")'."
            
            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return nil
        }
        
        return privateKey
    }
    
    private func getStatusHistory(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws -> StatusHistory? {
        let status = statusActivityPubEvent.status

        guard let statusHistory = try await StatusHistory.query(on: context.db)
            .filter(\.$orginalStatus.$id == status.requireID())
            .sort(\.$createdAt, .descending)
            .first() else {
            let errorMessage = "Status history cannot be downloaded from database for status '\(status.stringId() ?? "")'."
            
            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)
            
            context.logger.warning("\(errorMessage)")
            return nil
        }
        
        return statusHistory
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
        guard let announceDto = activityPubObject.object as? AnnouceDto,
              let objects = announceDto.object?.objects() else {
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

        // When we already have status in database we don't have to download it.
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

