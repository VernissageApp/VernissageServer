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
    struct ActivityPubIncomingServiceKey: StorageKey {
        typealias Value = ActivityPubIncomingServiceType
    }

    var activityPubIncomingService: ActivityPubIncomingServiceType {
        get {
            self.application.storage[ActivityPubIncomingServiceKey.self] ?? ActivityPubIncomingService()
        }
        nonmutating set {
            self.application.storage[ActivityPubIncomingServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ActivityPubIncomingServiceType: Sendable {
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

    /// Processes account migration from `Move` activity.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the move activity.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if migration processing fails.
    func move(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Determines whether an incoming undo activity should be processed.
    ///
    /// Evaluates the undo activity to decide if it should proceed for the given request and context.
    /// Returns `false` when referenced objects (like users or statuses) are missing, since there is nothing to undo.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the undo activity.
    ///   - context: The execution context providing services and database access.
    /// - Returns: `true` if the undo activity should be processed; otherwise, `false`.
    /// - Throws: Throws an error if evaluation fails.
    func shouldProcessUndo(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws -> Bool

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

    /// Processes a flag activity based on the ActivityPub request.
    ///
    /// Handles reports received from remote instances and stores them as non-local reports.
    ///
    /// - Parameters:
    ///   - activityPubRequest: The ActivityPub request DTO containing the flag activity.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the report cannot be created.
    func flag(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Processes inbound ActivityPub `Add` activity for featured collections.
    ///
    /// - Parameters:
    ///   - activityPubRequest: Incoming ActivityPub request payload.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if synchronization flow fails.
    func add(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Processes inbound ActivityPub `Remove` activity for featured collections.
    ///
    /// - Parameters:
    ///   - activityPubRequest: Incoming ActivityPub request payload.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if synchronization flow fails.
    func remove(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
}

/// Service responsible for consuming requests retrieved on Activity Pub controllers from remote instances.
final class ActivityPubIncomingService: ActivityPubIncomingServiceType {

    public func delete(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let statusesService = context.services.statusesService
        let usersService = context.services.usersService
        let activityPubSignatureService = context.services.activityPubSignatureService

        let objects = activityPubRequest.activity.object.objects()
        for object in objects {
            switch object.type {
            case .note, .tombstone:
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

                let actorId = activityPubRequest.activity.actor.actorIds().first
                let statusOwnerActivityPubProfile = statusToDelete.user.activityPubProfile
                guard actorId == statusOwnerActivityPubProfile else {
                    context.logger.warning("Cannot delete status because activity actor doesn't match status owner (activity: \(activityPubRequest.activity.id), actor: \(actorId ?? "<unknown>"), status: \(object.id), owner: \(statusOwnerActivityPubProfile)).")
                    continue
                }

                // Signature verified, we can delete status.
                try await statusesService.delete(id: statusToDelete.requireID(), on: context)
                context.logger.info("Deleting status: '\(object.id)'. Status deleted from local database successfully.")
            case .person, .service, .none:
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

                let actorId = activityPubRequest.activity.actor.actorIds().first
                let userActivityPubProfile = userToDelete.activityPubProfile
                guard actorId == userActivityPubProfile else {
                    context.logger.warning("Cannot delete user because activity actor doesn't match profile id (activity: \(activityPubRequest.activity.id), actor: \(actorId ?? "<unknown>"), profile: \(userActivityPubProfile)).")
                    continue
                }

                // Now we can delete user (and all user's references) from database.
                try await usersService.delete(remoteUser: userToDelete, on: context)
                context.logger.info("Deleting user: '\(object.id)'. User deleted from local database successfully.")
            case .profile:
                context.logger.info("Ignoring delete object of type 'Profile' (object: '\(object.id)').")
            default:
                context.logger.warning("Deleting object type: '\(object.type?.rawValue ?? "<unknown>")' is not supported yet.",
                                       metadata: [Constants.requestMetadata: activityPubRequest.bodyValue.loggerMetadata()])
            }
        }
    }

    public func create(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let activityPubDownloadUserService = context.services.activityPubDownloadUserService
        let userBlockedUsersService = context.services.userBlockedUsersService
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

                guard let activityPubProfile = activity.actor.actorIds().first else {
                    context.logger.warning("Cannot find any ActivityPub actor profile id (activity: \(activity.id)).")
                    continue
                }

                let shouldSuppressStatus = try await self.shouldSuppressStatus(noteDto: noteDto,
                                                                               activity: activity,
                                                                               activityPubProfile: activityPubProfile,
                                                                               on: context)
                if shouldSuppressStatus {
                    context.logger.warning("Status from suppressed user '\(activityPubProfile)' will not be added to the system (activity: \(activity.id)).")
                    return
                }

                // Determine whether the incoming status is public, quiet public, followers-only, or mentioned.
                let statusVisibility = self.resolveStatusVisibility(noteDto: noteDto, activity: activity)

                // Detect the local user targeted by this inbox endpoint when the activity came via /actors/:name/inbox.
                let userInboxRecipientId = try await self.userInboxRecipientId(for: activityPubRequest.httpPath, on: context)

                // Collect all local users explicitly addressed in to/cc so we can validate and route mentioned/direct statuses.
                let localRecipientUserIds = try await self.localRecipientUserIds(noteDto: noteDto, activity: activity, on: context)

                // Validations for regular status (with images).
                if noteDto.isComment() == false {

                    // Prevent creating new statuses when status doesn't contains any image.
                    guard let attachments = noteDto.attachment, !attachments.isEmpty, attachments.hasSupportedImages() else {
                        context.logger.warning("Status doesn't contain any image media type attachments (activity: \(activity.id)).")
                        continue
                    }

                    // Prevent creating new statuses when author is not followed by anyone in the instance.
                    let isRemoteUserFollowedByAnyone = try await self.isRemoteUserFollowedByAnyone(activityPubProfile: activityPubProfile, on: context)
                    if isRemoteUserFollowedByAnyone == false {
                        if statusVisibility == .mentioned, localRecipientUserIds.isEmpty == false {
                            context.logger.info("Processing mentioned status from unfollowed actor because local recipients exist (activity: \(activity.id)).")
                        } else {
                            context.logger.warning("Author of the status is not followed by anyone on the instance (activity: \(activity.id)).")
                            continue
                        }
                    }
                }

                if let userInboxRecipientId {
                    let shouldProcessForUserInbox = try await self.shouldProcessForUserInbox(recipientUserId: userInboxRecipientId,
                                                                                             sourceActorActivityPubProfile: activityPubProfile,
                                                                                             statusVisibility: statusVisibility,
                                                                                             localRecipientUserIds: localRecipientUserIds,
                                                                                             on: context)
                    if shouldProcessForUserInbox == false {
                        context.logger.info("Skipping create activity for user inbox recipient due to visibility/relationship rules (activity: \(activity.id), userId: \(userInboxRecipientId)).")
                        continue
                    }
                }

                // Get parent status from database (when inReplyTo is set).
                let parentStatusFromDatabase = try await self.getParentStatusInDatabase(replyToActivityPubId: noteDto.inReplyTo, on: context)

                // Validation for statuses which are comments to other statuses.
                if noteDto.isComment() == true {
                    // Prevent creating new statuses (comments) whene there is no commented (parent) status.
                    guard parentStatusFromDatabase != nil else {
                        context.logger.warning("Parent status '\(noteDto.inReplyTo ?? "")' for comment doesn't exists in the database (activity: \(activity.id)).")
                        continue
                    }
                }

                // Download user data (who created status) to local database.
                guard let user = try await activityPubDownloadUserService.downloadIfNeeded(activityPubProfile: activityPubProfile, on: context) else {
                    context.logger.warning("User '\(activity.actor.actorIds().first ?? "")' cannot found in the local database (activity: \(activity.id)).")
                    continue
                }

                // For comment status we need to verify also user blocks.
                if noteDto.isComment() == true, let parentStatusFromDatabase {
                    // We have to check if the author of parent status doesn't block the user.
                    let isUserBlockedByCommentAuthor = try await userBlockedUsersService.exists(userId: parentStatusFromDatabase.$user.id,
                                                                                                blockedUserId: user.requireID(),
                                                                                                on: context.db)

                    // User is blocked by the author of parent status.
                    if isUserBlockedByCommentAuthor {
                        continue
                    }

                    // Get main status (from chain of comments).
                    if let mainStatus = try await statusesService.getMainStatus(for: parentStatusFromDatabase.requireID(), on: context.db) {
                        // We have to check if the author of main status doesn't block the user.
                        let isUserBlockedByStatusAuthor = try await userBlockedUsersService.exists(userId: mainStatus.$user.id,
                                                                                                   blockedUserId: user.requireID(),
                                                                                                   on: context.db)

                        // User is blocked by the author of main status (photo). And to that photo blocked user cannot add anything.
                        if isUserBlockedByStatusAuthor {
                            continue
                        }
                    }
                }

                do {
                    // Create status into database.
                    let statusFromDatabase = try await statusesService.create(basedOn: noteDto,
                                                                              userId: user.requireID(),
                                                                              visibility: statusVisibility,
                                                                              on: context)

                    // Recalculate numer of user statuses.
                    try await statusesService.updateStatusCount(for: user.requireID(), on: context.application.db)

                    // Add new status to user's timelines (except comments).
                    if statusFromDatabase.$replyToStatus.id == nil {
                        switch statusFromDatabase.visibility {
                        case .public:
                            try await statusesService.createOnLocalTimeline(followersOf: user.requireID(), status: statusFromDatabase, on: context)
                            try await statusesService.createOnLocalTimelineForHashtagsFollowers(status: statusFromDatabase, on: context)
                        case .quietPublic, .followers:
                            try await statusesService.createOnLocalTimeline(followersOf: user.requireID(), status: statusFromDatabase, on: context)
                        case .mentioned:
                            try await statusesService.createOnLocalTimeline(mentionedUsers: localRecipientUserIds,
                                                                            status: statusFromDatabase,
                                                                            on: context)
                        }
                    }
                } catch StatusError.cannotAddCommentWithoutCommentedStatus {
                    // Consume this kind of error (it’s not a real error - we cannot create comment to not exists status).
                }
            default:
                context.logger.warning("Object type: '\(object.type?.rawValue ?? "<unknown>")' is not supported yet.",
                                       metadata: [Constants.requestMetadata: activityPubRequest.bodyValue.loggerMetadata()])
            }
        }
    }

    public func update(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let statusesService = context.services.statusesService
        let usersService = context.services.usersService
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

                let actorId = activity.actor.actorIds().first
                let statusOwnerActivityPubProfile = statusFromDatabase.user.activityPubProfile
                guard actorId == statusOwnerActivityPubProfile else {
                    context.logger.warning("Cannot update status because activity actor doesn't match status owner (activity: \(activity.id), actor: \(actorId ?? "<unknown>"), status: \(noteDto.id), owner: \(statusOwnerActivityPubProfile)).")
                    continue
                }

                // Update status into database.
                _ = try await statusesService.update(status: statusFromDatabase, basedOn: noteDto, on: context)
            case .person, .service:
                guard let personDto = object.object as? PersonDto else {
                    context.logger.warning("Cannot cast profile object to PersonDto (activity: \(activity.id).")
                    continue
                }

                guard let user = try await usersService.get(activityPubProfile: personDto.id, on: context.db) else {
                    context.logger.warning("Cannot update profile because user doesn't exist in local database (activity: \(personDto.id)).")
                    continue
                }

                guard user.isLocal == false else {
                    context.logger.warning("Cannot update local user based on remote profile update (activity: \(personDto.id)).")
                    continue
                }

                let actorId = activity.actor.actorIds().first
                let profileOwnerActivityPubProfile = user.activityPubProfile
                guard actorId == profileOwnerActivityPubProfile else {
                    context.logger.warning("Cannot update profile because activity actor doesn't match profile id (activity: \(activity.id), actor: \(actorId ?? "<unknown>"), profile: \(personDto.id)).")
                    continue
                }

                let profileIconFileName = await usersService.downloadProfileImage(personProfile: personDto, on: context)
                let profileImageFileName = await usersService.downloadHeaderImage(personProfile: personDto, on: context)

                // Update user in local database based on received ActivityPub profile.
                _ = try await usersService.update(user: user,
                                                  basedOn: personDto,
                                                  withAvatarFileName: profileIconFileName,
                                                  withHeaderFileName: profileImageFileName,
                                                  on: context)
            case .profile:
                context.logger.info("Ignoring update object of type 'Profile' (activity: \(activity.id), object: \(object.id)).")
            default:
                context.logger.warning("Object type: '\(object.type?.rawValue ?? "<unknown>")' is not supported yet for update.",
                                       metadata: [Constants.requestMetadata: activityPubRequest.bodyValue.loggerMetadata()])
            }
        }
    }

    public func follow(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let userBlockedDomainsService = context.services.userBlockedDomainsService
        let userBlockedUsersService = context.services.userBlockedUsersService
        let activity = activityPubRequest.activity

        guard let actorId = activity.actor.actorIds().first else {
            return
        }

        let objects = activity.object.objects()
        for object in objects {
            let domainIsBlockedByUser = try await userBlockedDomainsService.isDomainBlockedByUser(userActivityPubId: object.id, actorId: actorId, on: context)
            guard domainIsBlockedByUser == false else {
                context.logger.notice("Actor's domain: '\(actorId)' is blocked by user's (\(object.id)) domain blocks.")
                continue
            }

            let userIsBlockedByUser = try await userBlockedUsersService.isUserBlockedByUser(userActivityPubId: object.id, actorId: actorId, on: context)
            guard userIsBlockedByUser == false else {
                context.logger.notice("Actor: '\(actorId)' is blocked by user (\(object.id)) .")
                continue
            }

            try await self.follow(sourceProfileUrl: actorId, activityPubObject: object, activityId: activity.id, on: context)
        }
    }

    public func accept(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let activity = activityPubRequest.activity

        guard let targetActorId = activity.actor.actorIds().first else {
            return
        }

        let objects = activity.object.objects()
        for object in objects {
            try await self.accept(targetProfileUrl: targetActorId, activityPubObject: object, on: context)
        }
    }

    public func reject(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let activity = activityPubRequest.activity

        guard let targetActorId = activity.actor.actorIds().first else {
            return
        }

        let objects = activity.object.objects()
        for object in objects {
            try await self.reject(targetProfileUrl: targetActorId, activityPubObject: object, on: context)
        }
    }

    public func move(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        try await context.services.accountMigrationService.processMove(activityPubRequest: activityPubRequest, on: context)
    }

    func shouldProcessUndo(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws -> Bool {
        let usersService = context.services.usersService
        let statusesService = context.services.statusesService

        let activity = activityPubRequest.activity
        let objects = activity.object.objects()

        for object in objects {
            switch object.type {
            case .follow:
                guard let sourceActorId = activity.actor.actorIds().first,
                      let followDto = object.object as? FollowDto,
                      let followActors = followDto.object?.objects() else {
                    continue
                }

                guard let _ = try await usersService.get(activityPubProfile: sourceActorId, on: context.db) else {
                    continue
                }

                for followActor in followActors {
                    guard let _ = try await usersService.get(activityPubProfile: followActor.id, on: context.db) else {
                        continue
                    }

                    return true
                }
            case .announce:
                guard let sourceActorId = activity.actor.actorIds().first,
                      let announceDto = object.object as? AnnouceDto,
                      let announceObjects = announceDto.object?.objects() else {
                    continue
                }

                guard let _ = try await usersService.get(activityPubProfile: sourceActorId, on: context.db) else {
                    continue
                }

                for announceObject in announceObjects {
                    guard let _ = try await statusesService.get(activityPubId: announceObject.id, on: context.db) else {
                        continue
                    }

                    return true
                }
            case .like:
                guard let sourceActorId = activity.actor.actorIds().first,
                      let announceDto = object.object as? LikeDto,
                      let likeObjects = announceDto.object?.objects() else {
                    continue
                }

                guard let _ = try await usersService.get(activityPubProfile: sourceActorId, on: context.db) else {
                    continue
                }

                for likeObject in likeObjects {
                    guard let _ = try await statusesService.get(activityPubId: likeObject.id, on: context.db) else {
                        continue
                    }

                    return true
                }
            default:
                context.logger.warning("Undo of '\(object.type?.rawValue ?? "<unknown>")' action is not supported yet",
                                       metadata: [Constants.requestMetadata: activityPubRequest.bodyValue.loggerMetadata()])
                return false
            }
        }

        return false
    }

    func undo(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let activity = activityPubRequest.activity
        let objects = activity.object.objects()

        guard let sourceActorId = activity.actor.actorIds().first else {
            return
        }

        for object in objects {
            switch object.type {
            case .follow:
                try await self.unfollow(sourceActorId: sourceActorId, activityPubObject: object, on: context)
            case .announce:
                try await self.unannounce(sourceActorId: sourceActorId, activityPubObject: object, on: context)
            case .like:
                try await self.unlike(sourceActorId: sourceActorId, activityPubObject: object, on: context)
            default:
                context.logger.warning("Undo of '\(object.type?.rawValue ?? "<unknown>")' action is not supported yet",
                                       metadata: [Constants.requestMetadata: activityPubRequest.bodyValue.loggerMetadata()])
            }
        }
    }

    public func like(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let statusesService = context.services.statusesService
        let activityPubDownloadUserService = context.services.activityPubDownloadUserService
        let activity = activityPubRequest.activity

        // Download user data (who liked status) to local database.
        guard let actorActivityPubId = activity.actor.actorIds().first,
              let remoteUser = try await activityPubDownloadUserService.downloadIfNeeded(activityPubProfile: actorActivityPubId, on: context) else {
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
        let instanceBlockedDomainsService = context.services.instanceBlockedDomainsService

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

        if remoteUser.isSuppressed {
            context.logger.warning("Boost from suppressed user '\(actorActivityPubId)' will not be added to the system (activity: \(activity.id)).")
            return
        }

        for object in objects {
            // Check if announced object is from instance blocked domain.
            if try await instanceBlockedDomainsService.isDomainBlockedByInstance(activityPubId: object.id, on: context) {
                context.logger.warning("Boosted status '\(object.id)' has not been downloaded because its domain is blocked by the instance (activity: \(activity.id)).")
                continue
            }

            if try await self.isOwnerSuppressed(of: object, on: context) {
                context.logger.warning("Boosted status '\(object.id)' belongs to a suppressed user and will not be added to the system (activity: \(activity.id)).")
                continue
            }

            // Create (or get from local database) main status in local database.
            let downloadedStatus = try await self.downloadStatusSuppressingErrors(activityPubId: object.id, on: context)
            guard let downloadedStatus else {
                context.logger.warning("Boosted status '\(object.id)' has not been added to the system (activity: \(activity.id)).")
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

            let remoteUserId = try remoteUser.requireID()
            let mainStatusId = try mainStatusFromDatabase.requireID()

            let existingReblog = try await Status.query(on: context.db)
                .filter(\.$user.$id == remoteUserId)
                .filter(\.$reblog.$id == mainStatusId)
                .first()

            if existingReblog != nil {
                context.logger.info("Skipping duplicate announce for status '\(object.id)' by actor '\(actorActivityPubId)' (activity: \(activity.id)).")
                continue
            }

            // Create reblog status.
            let statusId = context.application.services.snowflakeService.generate()
            let reblogStatus = Status(id: statusId,
                                      isLocal: false,
                                      userId: remoteUserId,
                                      note: nil,
                                      baseAddress: baseAddress,
                                      userName: remoteUser.userName,
                                      application: nil,
                                      categoryId: nil,
                                      visibility: .public,
                                      reblogId: mainStatusId,
                                      publishedAt: Date())

            try await reblogStatus.create(on: context.db)
            try await statusesService.updateReblogsCount(for: mainStatusFromDatabase.requireID(), on: context.db)

            // Add new notification (when remote user reblog local status).
            if mainStatusFromDatabase.isLocal {
                let notificationsService = context.application.services.notificationsService
                try await notificationsService.create(type: .reblog,
                                                      to: mainStatusFromDatabase.user,
                                                      by: remoteUserId,
                                                      statusId: mainStatusId,
                                                      mainStatusId: nil,
                                                      on: context)
            }

            // Add new reblog status to user's timelines.
            context.logger.info("Connecting status '\(reblogStatus.stringId() ?? "")' to followers of '\(remoteUser.stringId() ?? "")'.")
            try await statusesService.createOnLocalTimeline(followersOf: remoteUserId, status: reblogStatus, on: context)

            // Status should be processed by following hashtags mechanism only when it was created.
            if let downloadedStatusCreatedAt = downloadedStatus.createdAt,
               downloadedStatusCreatedAt > Date.minuteAgo {
                try await statusesService.createOnLocalTimelineForHashtagsFollowers(status: mainStatusFromDatabase, on: context)
            }
        }
    }

    private func isOwnerSuppressed(of object: ObjectDto, on context: ExecutionContext) async throws -> Bool {
        guard let noteDto = object.object as? NoteDto,
              let user = try await context.services.usersService.get(activityPubProfile: noteDto.attributedTo, on: context.db) else {
            return false
        }

        return user.isSuppressed
    }

    public func flag(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        let activity = activityPubRequest.activity
        let statusesService = context.services.statusesService
        let activityPubDownloadUserService = context.services.activityPubDownloadUserService

        let objects = activity.object.objects()
        let reportedStatus = try await self.reportedLocalStatus(from: objects, on: context)
        let reportedUser = try await self.reportedLocalUser(from: objects, status: reportedStatus, on: context)

        guard let reportedUser else {
            context.logger.warning("Cannot create report from Flag because there is no local reported user or status (activity: \(activity.id)).")
            return
        }

        if let report = try await Report.query(on: context.db)
            .filter(\.$activityPubId == activity.id)
            .first() {
            context.logger.info("Report from ActivityPub Flag already exists (report: \(report.stringId() ?? ""), activity: \(activity.id)).")
            return
        }

        guard let actorActivityPubId = activity.actor.actorIds().first else {
            context.logger.warning("Cannot find any ActivityPub actor profile id (activity: \(activity.id)).")
            return
        }

        guard let reportingUser = try await activityPubDownloadUserService.downloadIfNeeded(activityPubProfile: actorActivityPubId, on: context) else {
            context.logger.warning("Reporting user '\(actorActivityPubId)' cannot be found in the local database (activity: \(activity.id)).")
            return
        }

        let reportedStatusId = try reportedStatus?.requireID()
        let mainStatus = try await statusesService.getMainStatus(for: reportedStatusId, on: context.db)
        let reportId = context.services.snowflakeService.generate()

        let report = Report(id: reportId,
                            userId: try reportingUser.requireID(),
                            reportedUserId: try reportedUser.requireID(),
                            statusId: reportedStatusId,
                            mainStatusId: mainStatus?.id,
                            comment: activity.content,
                            forward: false,
                            isLocal: false,
                            activityPubId: activity.id,
                            category: nil,
                            ruleIds: nil)

        try await report.save(on: context.db)
        try await self.sendAdminReportNotifications(reportedUser: reportedUser, on: context)
        context.logger.info("Report (id: '\(reportId)') has been created from ActivityPub Flag (activity: \(activity.id)).")
    }

    func add(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        try await self.refreshRemoteUser(activityPubRequest: activityPubRequest, action: "Add", on: context)
    }

    func remove(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        try await self.refreshRemoteUser(activityPubRequest: activityPubRequest, action: "Remove", on: context)
    }

    private func downloadStatusSuppressingErrors(activityPubId: String, on context: ExecutionContext) async throws -> Status? {
        do {
            let activityPubDownloadStatusService = context.services.activityPubDownloadStatusService
            let downloadedStatus = try await activityPubDownloadStatusService.download(activityPubId: activityPubId, on: context)
            return downloadedStatus
        } catch ActivityPubError.missingSupportedImageAttachments {
            // Consume this kind of error (it’s not a real error - statuses without images are simply not supported).
        } catch StatusError.cannotAddCommentWithoutCommentedStatus {
            // Consume this kind of error (it’s not a real error - we cannot create comment to not exists status).
        } catch ActivityPubError.actorIsSuppressedByInstance {
            // Consume this kind of error (status belongs to an intentionally suppressed actor).
        }

        return nil
    }
    
    private func reportedLocalStatus(from objects: [ObjectDto], on context: ExecutionContext) async throws -> Status? {
        let statusesService = context.services.statusesService

        for object in objects {
            guard let status = try await statusesService.get(activityPubId: object.id, on: context.db), status.isLocal else {
                continue
            }

            return status
        }

        return nil
    }

    private func reportedLocalUser(from objects: [ObjectDto], status: Status?, on context: ExecutionContext) async throws -> User? {
        if let status {
            return status.user
        }

        let usersService = context.services.usersService
        for object in objects {
            guard let user = try await usersService.get(activityPubProfile: object.id, on: context.db), user.isLocal else {
                continue
            }

            return user
        }

        return nil
    }

    private func sendAdminReportNotifications(reportedUser: User, on context: ExecutionContext) async throws {
        let notificationsService = context.services.notificationsService
        let usersService = context.services.usersService

        let moderators = try await usersService.getModerators(on: context.db)
        for moderator in moderators {
            try await notificationsService.create(type: .adminReport,
                                                  to: moderator,
                                                  by: reportedUser.requireID(),
                                                  statusId: nil,
                                                  mainStatusId: nil,
                                                  on: context)
        }
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
        try await statusesService.delete(id: statusId, on: context)

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

        let activityPubDownloadUserService = context.services.activityPubDownloadUserService
        let followsService = context.services.followsService
        let usersService = context.services.usersService

        // Download profile from remote server.
        context.logger.info("Downloading account \(sourceProfileUrl) from remote server.")

        let remoteUser = try await activityPubDownloadUserService.downloadIfNeeded(activityPubProfile: sourceProfileUrl, on: context)
        guard let remoteUser else {
            context.logger.warning("Account '\(sourceProfileUrl)' cannot be downloaded from remote server.")
            return
        }

        let targetUser = try await usersService.get(activityPubProfile: activityPubObject.id, on: context.db)
        guard let targetUser else {
            context.logger.warning("Cannot find local user '\(activityPubObject.id)'.")
            return
        }

        // Account has been moved elsewhere and should not accept new followers.
        if targetUser.$movedTo.id != nil {
            try await self.respondReject(requesting: remoteUser.activityPubProfile,
                                         asked: targetUser.activityPubProfile,
                                         inbox: remoteUser.userInbox,
                                         withId: remoteUser.requireID(),
                                         rejectedId: activityId,
                                         privateKey: targetUser.privateKey,
                                         on: context)
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

        guard let sourceProfileUrl = followDto.actor?.actorIds().first else {
            return
        }

        try await self.accept(sourceProfileUrl: sourceProfileUrl, targetProfileUrl: targetProfileUrl, on: context)
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

        guard let sourceProfileUrl = followDto.actor?.actorIds().first else {
            return
        }

        try await self.reject(sourceProfileUrl: sourceProfileUrl, targetProfileUrl: targetProfileUrl, on: context)
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

    private func respondReject(requesting: String,
                               asked: String,
                               inbox: String?,
                               withId id: Int64,
                               rejectedId: String,
                               privateKey: String?,
                               on context: ExecutionContext) async throws {
        guard let inbox, let inboxUrl = URL(string: inbox) else {
            return
        }

        guard let privateKey else {
            return
        }

        let activityPubFollowRespondDto = ActivityPubFollowRespondDto(approved: false,
                                                                      requesting: requesting,
                                                                      asked: asked,
                                                                      inbox: inboxUrl,
                                                                      id: id,
                                                                      orginalRequestId: rejectedId,
                                                                      privateKey: privateKey)

        try await context
            .queues(.apFollowResponder)
            .dispatch(ActivityPubFollowResponderJob.self, activityPubFollowRespondDto)
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

    private func shouldSuppressStatus(noteDto: NoteDto,
                                      activity: ActivityDto,
                                      activityPubProfile: String,
                                      on context: ExecutionContext) async throws -> Bool {
        guard activity.type == .create,
              noteDto.isComment() == false,
              let attachments = noteDto.attachment,
              attachments.isEmpty == false,
              attachments.hasSupportedImages() else {
            return false
        }

        let usersService = context.services.usersService
        let user = try await usersService.get(activityPubProfile: activityPubProfile, on: context.db)
        return user?.isSuppressed == true
    }

    private func resolveStatusVisibility(noteDto: NoteDto, activity: ActivityDto) -> StatusVisibility {
        let publicAddress = "https://www.w3.org/ns/activitystreams#Public"
        let toActorIds = noteDto.to?.actorIds() ?? activity.to?.actorIds() ?? []
        let ccActorIds = noteDto.cc?.actorIds() ?? activity.cc?.actorIds() ?? []
        let allActorIds = toActorIds + ccActorIds

        // Public in "to" means fully public post visible to everyone.
        if toActorIds.contains(publicAddress) {
            return .public
        }

        // Public in "cc" means unlisted/quiet public post shared without direct public addressing.
        if ccActorIds.contains(publicAddress) {
            return .quietPublic
        }

        // Addressing followers collection indicates followers-only visibility.
        if allActorIds.contains(where: { $0.hasSuffix("/followers") }) {
            return .followers
        }

        // If none of the above matched, treat it as direct/mentioned visibility.
        return .mentioned
    }

    private func userInboxRecipientId(for requestPath: ActivityPubRequestPath, on context: ExecutionContext) async throws -> Int64? {
        let usersService = context.services.usersService

        switch requestPath {
        case .userInbox(let userName):
            return try await usersService.get(userName: userName, on: context.db)?.id
        case .applicationUserInbox:
            return try await usersService.getDefaultSystemUser(on: context.db)?.id
        default:
            return nil
        }
    }

    private func localRecipientUserIds(noteDto: NoteDto, activity: ActivityDto, on context: ExecutionContext) async throws -> [Int64] {
        let publicAddress = "https://www.w3.org/ns/activitystreams#Public"
        let usersService = context.services.usersService
        let noteRecipientIds = (noteDto.to?.actorIds() ?? []) + (noteDto.cc?.actorIds() ?? [])
        let activityRecipientIds = (activity.to?.actorIds() ?? []) + (activity.cc?.actorIds() ?? [])
        let recipientIds = noteRecipientIds.isEmpty ? activityRecipientIds : noteRecipientIds

        var userIds: Set<Int64> = []
        for recipientId in recipientIds {
            // Skip the global Public address because it is not a concrete local recipient.
            if recipientId == publicAddress {
                continue
            }

            let actorId = recipientId.hasSuffix("/followers")
                ? String(recipientId.dropLast("/followers".count))
                : recipientId

            guard let user = try await usersService.get(activityPubProfile: actorId, on: context.db),
                  user.isLocal else {
                continue
            }

            userIds.insert(try user.requireID())
        }

        return Array(userIds)
    }

    private func shouldProcessForUserInbox(recipientUserId: Int64,
                                           sourceActorActivityPubProfile: String,
                                           statusVisibility: StatusVisibility,
                                           localRecipientUserIds: [Int64],
                                           on context: ExecutionContext) async throws -> Bool {
        // Always process when the inbox owner is explicitly addressed in to/cc.
        if localRecipientUserIds.contains(recipientUserId) {
            return true
        }

        // Reject direct/mentioned activities for this inbox when recipient is not explicitly addressed.
        if statusVisibility == .mentioned {
            return false
        }

        // Public activities are allowed for user inbox processing even without explicit mention.
        if statusVisibility == .public {
            return true
        }

        let usersService = context.services.usersService
        guard let sourceUser = try await usersService.get(activityPubProfile: sourceActorActivityPubProfile, on: context.db) else {
            return false
        }

        let sourceUserId = try sourceUser.requireID()
        let follow = try await Follow.query(on: context.db)
            .filter(\.$source.$id == recipientUserId)
            .filter(\.$target.$id == sourceUserId)
            .filter(\.$approved == true)
            .first()

        return follow != nil
    }

    private func refreshRemoteUser(activityPubRequest: ActivityPubRequestDto, action: String, on context: ExecutionContext) async throws {
        guard let actorId = activityPubRequest.activity.actor.actorIds().first else {
            context.logger.warning("Cannot process '\(action)' for featured collection. Missing actor id.")
            return
        }

        let targetIds = activityPubRequest.activity.target?.actorIds() ?? []
        guard targetIds.isEmpty == false else {
            context.logger.info("Skipping '\(action)' activity without target collection.")
            return
        }

        let usersService = context.services.usersService
        guard let userFromDatabase = try await usersService.get(activityPubProfile: actorId, on: context.db) else {
            context.logger.info("Skipping '\(action)' activity for unknown actor: '\(actorId)'.")
            return
        }

        let collectionsService = context.services.collectionsService
        if let featuredCollection = userFromDatabase.featured?.nilIfEmpty {
            guard targetIds.contains(featuredCollection) else {
                context.logger.info("Skipping '\(action)' activity for non-featured target.")
                return
            }

            try await collectionsService.synchronizeFeaturedCollection(for: userFromDatabase.requireID(), on: context)
            return
        }

        let isRemoteUserFollowedByAnyone = try await self.isRemoteUserFollowedByAnyone(activityPubProfile: actorId, on: context)
        guard isRemoteUserFollowedByAnyone else {
            context.logger.info("Skipping '\(action)' featured refresh. Remote actor is not followed by any local user: '\(actorId)'.")
            return
        }

        let activityPubDownloadUserService = context.services.activityPubDownloadUserService
        let refreshedUser = try await activityPubDownloadUserService.refreshRemoteUser(activityPubProfile: actorId, on: context) ?? userFromDatabase

        guard let featuredCollection = refreshedUser.featured?.nilIfEmpty else {
            context.logger.info("Skipping '\(action)' activity for actor without featured collection: '\(actorId)'.")
            return
        }

        guard targetIds.contains(featuredCollection) else {
            context.logger.info("Skipping '\(action)' activity for non-featured target.")
            return
        }

        try await collectionsService.synchronizeFeaturedCollection(for: refreshedUser.requireID(), on: context)
    }

    private func getParentStatusInDatabase(replyToActivityPubId: String?, on context: ExecutionContext) async throws -> Status? {
        guard let replyToActivityPubId else {
            return nil
        }

        let statusesService = context.services.statusesService
        guard let status = try await statusesService.get(activityPubId: replyToActivityPubId, on: context.db) else {
            return nil
        }

        return status
    }

    private func isLocalObjectOnTheList(objects: [ObjectDto], baseAddress: String) -> Bool {
        return objects.contains { $0.id.starts(with: "\(baseAddress)/") }
    }
}
