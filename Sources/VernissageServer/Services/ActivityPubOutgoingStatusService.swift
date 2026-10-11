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
    struct ActivityPubOutgoingStatusServiceKey: StorageKey {
        typealias Value = ActivityPubOutgoingStatusServiceType
    }

    var activityPubOutgoingStatusService: ActivityPubOutgoingStatusServiceType {
        get {
            self.application.storage[ActivityPubOutgoingStatusServiceKey.self] ?? ActivityPubOutgoingStatusService()
        }
        nonmutating set {
            self.application.storage[ActivityPubOutgoingStatusServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ActivityPubOutgoingStatusServiceType: Sendable {
    /// Creates and distributes a status based on the given ActivityPub status event.
    ///
    /// Sends ordinary statuses to shared inboxes and direct messages only to explicit recipients' personal inboxes.
    /// Failed private deliveries throw so the queue can retry, skipping inboxes that have already succeeded.
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

    /// Deletes a remote status given its ActivityPub Id and related identifiers.
    ///
    /// - Parameters:
    ///   - statusActivityPubId: The ActivityPub ID of the status.
    ///   - userId: The user identifier requesting deletion.
    ///   - statusId: The internal status identifier.
    ///   - context: The execution context for database and services.
    /// - Throws: An error if deletion fails.
    func delete(statusActivityPubId: String, userId: Int64, statusId: Int64, on context: ExecutionContext) async throws
    
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

    /// Creates and distributes a pin activity (`Add` to featured collection) based on the given status event.
    ///
    /// - Parameters:
    ///   - statusActivityPubEvent: The event describing the pin action and its distribution targets.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the pin cannot be sent, or if validation or processing fails.
    func pin(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws

    /// Creates and distributes an unpin activity (`Remove` from featured collection) based on the given status event.
    ///
    /// - Parameters:
    ///   - statusActivityPubEvent: The event describing the unpin action and its distribution targets.
    ///   - context: The execution context providing services and database access.
    /// - Throws: Throws an error if the unpin cannot be sent, or if validation or processing fails.
    func unpin(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws
}

/// Service responsible for sending requests to Activity Pub remote instances.
final class ActivityPubOutgoingStatusService: ActivityPubOutgoingStatusServiceType {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func create(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        let statusesService = context.services.statusesService
        let suspendedServersService = context.services.suspendedServersService

        guard let status = try await self.getStatus(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            if status.$directConversation.id != nil {
                throw Abort(.internalServerError, reason: "Missing direct-message signing key.")
            }

            return
        }

        // Get information about reply status.
        let replyToStatus: Status? = if let replyToStatusId = status.$replyToStatus.id {
            try await statusesService.get(id: replyToStatusId, on: context.application.db)
        } else {
            nil
        }

        // Download suspended servers list.
        let suspendedServers = await suspendedServersService.getSnapshot(on: context)

        // Prepare note DTO object.
        let noteDto = try await statusesService.note(basedOn: status, replyToStatus: replyToStatus, on: context)

        let isDirectMessage = status.$directConversation.id != nil
        let allowedInboxes: Set<String>

        if isDirectMessage {
            // Defense in depth: a private event cannot deliver to a shared inbox or an earlier audience.
            let recipients = try await StatusRecipient.query(on: context.db)
                .filter(\.$status.$id == status.requireID())
                .with(\.$user)
                .all()
            allowedInboxes = Set(recipients.map(\.user).filter { $0.isLocal == false }.compactMap(\.userInbox))
        } else {
            allowedInboxes = []
        }

        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter {
            isDirectMessage ? $0.isSuccess != true : $0.isSuccess == nil
        }

        // Send created note to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            try await eventItem.start(on: context)

            guard isDirectMessage == false || allowedInboxes.contains(eventItem.url) else {
                try await eventItem.error("Destination is not an explicit direct-message recipient inbox.", on: context)
                continue
            }

            // Translate string into URL.
            guard let sharedInboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Status: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."

                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }

            let shouldSend = await suspendedServersService.shouldSend(to: sharedInboxUrl.host, basedOn: suspendedServers)
            guard shouldSend else {
                try? await eventItem.suspended(on: context)
                context.logger.warning("Sending create status skipped for suspended host: '\(sharedInboxUrl.host ?? "<unknown>")'.")
                continue
            }

            // Prepare ActivityPub client.
            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending create status: '\(status.stringId() ?? "")' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey,
                                                      userAgent: Constants.userAgent,
                                                      host: sharedInboxUrl.host,
                                                      urlSession: urlSession)

            do {
                // Send status create via network to remote server.
                try await activityPubClient.create(note: noteDto,
                                                   activityPubProfile: noteDto.attributedTo,
                                                   activityPubReplyProfile: replyToStatus?.user.activityPubProfile,
                                                   on: sharedInboxUrl)

                // Mark event item as finished successfully.
                try? await eventItem.success(on: context)
                try? await suspendedServersService.registerSuccess(for: sharedInboxUrl.host, on: context)
            } catch {
                // Mark event item as finished with error.
                let message = isDirectMessage ? "Direct-message inbox delivery failed." : "\(error)"
                try? await eventItem.error(message, on: context)
                try? await suspendedServersService.registerConnectionError(for: sharedInboxUrl.host, error: error, on: context)
                context.logger.warning("Sending create status to inbox error. Inbox url: \(sharedInboxUrl). Error: \(message).")
            }
        }

        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false || $0.isSuspended == true })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)

        if isDirectMessage && hasFailedEvents {
            // RetryableAsyncJob retries failures. Successful inboxes are skipped on each subsequent attempt.
            throw Abort(.badGateway, reason: "Direct-message delivery failed for one or more inboxes.")
        }
    }

    public func update(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        let statusesService = context.services.statusesService
        let suspendedServersService = context.services.suspendedServersService

        guard let status = try await self.getStatus(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

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

        // Download suspended servers list.
        let suspendedServers = await suspendedServersService.getSnapshot(on: context)

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

            let shouldSend = await suspendedServersService.shouldSend(to: sharedInboxUrl.host, basedOn: suspendedServers)
            guard shouldSend else {
                try? await eventItem.suspended(on: context)
                context.logger.warning("Sending update status skipped for suspended host: '\(sharedInboxUrl.host ?? "<unknown>")'.")
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
                try? await suspendedServersService.registerSuccess(for: sharedInboxUrl.host, on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                try? await suspendedServersService.registerConnectionError(for: sharedInboxUrl.host, error: error, on: context)
                context.logger.warning("Sending update status to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }

        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false || $0.isSuspended == true })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }
    
    func delete(statusActivityPubId: String, userId: Int64, statusId: Int64, on context: ExecutionContext) async throws {
        // The status has already been removed. Its content-free marker retains the original private audience.
        // Always branch before calculating public followers or shared inboxes.
        if let deleted = try await DeletedDirectMessage.find(statusId, on: context.db) {
            try await deleteDirectMessage(deleted, userId: userId, on: context)

            return
        }

        let followsService = context.services.followsService
        let statusesService = context.services.statusesService

        guard let user = try await User.query(on: context.db)
            .filter(\.$id == userId)
            .withDeleted()
            .first() else {
            context.logger.warning("User: '\(userId)' cannot exists in database.")
            return
        }

        guard let privateKey = user.privateKey else {
            context.logger.warning("Status: '\(statusActivityPubId)' cannot be send to shared inbox (delete). Missing private key.")
            return
        }

        let users = try await User.query(on: context.db)
            .filter(\.$isLocal == false)
            .field(\.$sharedInbox)
            .unique()
            .all()

        // All shared inboxes.
        let allSharedInboxes = users.map({  $0.sharedInbox })

        // Calculate followers shared inboxes.
        let followersSharedInboxes = try await followsService.getFollowersOfSharedInboxes(followersOf: userId, on: context)

        // Calculate commentators shared inboxes.
        let commentatorsSharedInboxes = try await statusesService.getCommentatorsSharedInboxes(statusId: statusId, on: context)

        // All combined shared inboxes.
        let sharedInboxesSet = Array(followersSharedInboxes + commentatorsSharedInboxes + allSharedInboxes).unique()

        for (index, sharedInbox) in sharedInboxesSet.enumerated() {
            guard let sharedInbox, let sharedInboxUrl = URL(string: sharedInbox) else {
                context.logger.warning("Status delete: '\(statusActivityPubId)' cannot be send to shared inbox url: '\(sharedInbox ?? "")'.")
                continue
            }

            context.logger.info("[\(index + 1)/\(sharedInboxesSet.count)] Sending status delete: '\(statusActivityPubId)' to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: sharedInboxUrl.host)

            do {
                try await activityPubClient.delete(actorId: user.activityPubProfile, statusId: statusActivityPubId, on: sharedInboxUrl)
            } catch {
                context.logger.warning("Sending status delete to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }
    }

    public func like(statusActivityPubEvent: StatusActivityPubEvent, statusFavouriteId: String?, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        if let status = try await self.getStatus(statusActivityPubEvent: statusActivityPubEvent, on: context),
           status.$directConversation.id != nil {
            try await self.sendDirectMessageReaction(event: statusActivityPubEvent,
                                                     status: status,
                                                     favouriteId: statusFavouriteId,
                                                     undo: false,
                                                     on: context)

            return
        }

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        let usersService = context.services.usersService
        let suspendedServersService = context.services.suspendedServersService

        guard let status = try await self.getStatus(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        guard let user = try await usersService.get(id: statusActivityPubEvent.user.requireID(), on: context.db) else {
            return
        }

        guard let statusFavouriteId else {
            let errorMessage = "Status favourite: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing status favourite id."

            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return
        }

        // Download suspended servers list.
        let suspendedServers = await suspendedServersService.getSnapshot(on: context)

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

            let shouldSend = await suspendedServersService.shouldSend(to: sharedInboxUrl.host, basedOn: suspendedServers)
            guard shouldSend else {
                try? await eventItem.suspended(on: context)
                context.logger.warning("Sending favourite skipped for suspended host: '\(sharedInboxUrl.host ?? "<unknown>")'.")
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
                try? await suspendedServersService.registerSuccess(for: sharedInboxUrl.host, on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                try? await suspendedServersService.registerConnectionError(for: sharedInboxUrl.host, error: error, on: context)
                context.logger.warning("Sending favourite to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }

        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false || $0.isSuspended == true })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }

    public func unlike(statusActivityPubEvent: StatusActivityPubEvent, statusFavouriteId: String?, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        if let status = try await self.getStatus(statusActivityPubEvent: statusActivityPubEvent, on: context),
           status.$directConversation.id != nil {
            try await self.sendDirectMessageReaction(event: statusActivityPubEvent,
                                                     status: status,
                                                     favouriteId: statusFavouriteId,
                                                     undo: true,
                                                     on: context)

            return
        }

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        let usersService = context.services.usersService
        let suspendedServersService = context.services.suspendedServersService

        guard let status = try await self.getStatus(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        guard let user = try await usersService.get(id: statusActivityPubEvent.user.requireID(), on: context.db) else {
            return
        }

        guard let statusFavouriteId else {
            let errorMessage = "Status unfavourite: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing status favourite id."

            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return
        }

        // Download suspended servers list.
        let suspendedServers = await suspendedServersService.getSnapshot(on: context)

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

            let shouldSend = await suspendedServersService.shouldSend(to: sharedInboxUrl.host, basedOn: suspendedServers)
            guard shouldSend else {
                try? await eventItem.suspended(on: context)
                context.logger.warning("Sending unfavourite skipped for suspended host: '\(sharedInboxUrl.host ?? "<unknown>")'.")
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
                try? await suspendedServersService.registerSuccess(for: sharedInboxUrl.host, on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                try? await suspendedServersService.registerConnectionError(for: sharedInboxUrl.host, error: error, on: context)
                context.logger.warning("Sending unfavourite to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }

        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false || $0.isSuspended == true })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }

    public func announce(statusActivityPubEvent: StatusActivityPubEvent, activityPubReblog: ActivityPubReblogDto?, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        let suspendedServersService = context.services.suspendedServersService

        guard let status = try await self.getStatus(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        guard let activityPubReblog else {
            let errorMessage = "Status announce: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing announce data."

            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return
        }

        // Download suspended servers list.
        let suspendedServers = await suspendedServersService.getSnapshot(on: context)

        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter { $0.isSuccess == nil }

        // Send updated note to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            try await eventItem.start(on: context)

            // Translate string into URL.
            guard let sharedInboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Announce: '\(activityPubReblog.activityPubStatusId)' (orginal status id: '\(status.stringId() ?? "")') cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."

                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }

            let shouldSend = await suspendedServersService.shouldSend(to: sharedInboxUrl.host, basedOn: suspendedServers)
            guard shouldSend else {
                try? await eventItem.suspended(on: context)
                context.logger.warning("Sending announce skipped for suspended host: '\(sharedInboxUrl.host ?? "<unknown>")'.")
                continue
            }

            // Prepare ActivityPub client.
            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending announce: '\(activityPubReblog.activityPubStatusId)' (orginal status id: '\(status.stringId() ?? "")') to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
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
                try? await suspendedServersService.registerSuccess(for: sharedInboxUrl.host, on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                try? await suspendedServersService.registerConnectionError(for: sharedInboxUrl.host, error: error, on: context)
                context.logger.warning("Sending announce to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }

        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false || $0.isSuspended == true })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }

    public func unannounce(statusActivityPubEvent: StatusActivityPubEvent, activityPubUnreblog: ActivityPubUnreblogDto?, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        let suspendedServersService = context.services.suspendedServersService

        guard let status = try await self.getStatus(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        guard let activityPubUnreblog else {
            let errorMessage = "Status unannounce: '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing unannounce data."

            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return
        }

        // Download suspended servers list.
        let suspendedServers = await suspendedServersService.getSnapshot(on: context)

        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter { $0.isSuccess == nil }

        // Send updated note to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            try await eventItem.start(on: context)

            // Translate string into URL.
            guard let sharedInboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Unannounce: '\(activityPubUnreblog.activityPubStatusId)' (orginal status id: '\(status.stringId() ?? "")') cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."

                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }

            let shouldSend = await suspendedServersService.shouldSend(to: sharedInboxUrl.host, basedOn: suspendedServers)
            guard shouldSend else {
                try? await eventItem.suspended(on: context)
                context.logger.warning("Sending unannounce skipped for suspended host: '\(sharedInboxUrl.host ?? "<unknown>")'.")
                continue
            }

            // Prepare ActivityPub client.
            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending unannounce: '\(activityPubUnreblog.activityPubStatusId)' (orginal status id: '\(status.stringId() ?? "")') to shared inbox: '\(sharedInboxUrl.absoluteString)'.")
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
                try? await suspendedServersService.registerSuccess(for: sharedInboxUrl.host, on: context)
            } catch {
                // Mark event item as finished with error.
                try? await eventItem.error("\(error)", on: context)
                try? await suspendedServersService.registerConnectionError(for: sharedInboxUrl.host, error: error, on: context)
                context.logger.warning("Sending unannounce to shared inbox error. Shared inbox url: \(sharedInboxUrl). Error: \(error).")
            }
        }

        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false || $0.isSuspended == true })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }

    public func pin(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        let suspendedServersService = context.services.suspendedServersService
        let snowflakeService = context.services.snowflakeService

        guard let status = try await self.getStatus(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        let user = statusActivityPubEvent.user
        let featuredCollection = user.featured ?? "\(user.activityPubProfile)/featured"

        // Download suspended servers list.
        let suspendedServers = await suspendedServersService.getSnapshot(on: context)

        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter { $0.isSuccess == nil }

        // Send Add activity to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            try await eventItem.start(on: context)

            guard let inboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Pin: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."

                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }

            let shouldSend = await suspendedServersService.shouldSend(to: inboxUrl.host, basedOn: suspendedServers)
            guard shouldSend else {
                try? await eventItem.suspended(on: context)
                context.logger.warning("Sending pin skipped for suspended host: '\(inboxUrl.host ?? "<unknown>")'.")
                continue
            }

            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending pin: '\(status.stringId() ?? "")' to shared inbox: '\(inboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: inboxUrl.host)
            let requestId = snowflakeService.generate()

            do {
                try await activityPubClient.addToFeatured(objectId: status.activityPubId,
                                                          actorId: user.activityPubProfile,
                                                          targetId: featuredCollection,
                                                          on: inboxUrl,
                                                          withId: requestId)

                try? await eventItem.success(on: context)
                try? await suspendedServersService.registerSuccess(for: inboxUrl.host, on: context)
            } catch {
                try? await eventItem.error("\(error)", on: context)
                try? await suspendedServersService.registerConnectionError(for: inboxUrl.host, error: error, on: context)
                context.logger.warning("Sending pin to shared inbox error. Shared inbox url: \(inboxUrl). Error: \(error).")
            }
        }

        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false || $0.isSuspended == true })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }

    public func unpin(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws {
        try await statusActivityPubEvent.start(on: context)

        // Private key is required for sending ActivityPub request.
        guard let privateKey = try await self.getPrivateKey(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        let suspendedServersService = context.services.suspendedServersService
        let snowflakeService = context.services.snowflakeService

        guard let status = try await self.getStatus(statusActivityPubEvent: statusActivityPubEvent, on: context) else {
            return
        }

        let user = statusActivityPubEvent.user
        let featuredCollection = user.featured ?? "\(user.activityPubProfile)/featured"

        // Download suspended servers list.
        let suspendedServers = await suspendedServersService.getSnapshot(on: context)

        // Try to send update only to hosts which we didn't sent update yet.
        let eventItemsToProceed = statusActivityPubEvent.statusActivityPubEventItems.filter { $0.isSuccess == nil }

        // Send Remove activity to all inboxes.
        for (index, eventItem) in eventItemsToProceed.enumerated() {
            try await eventItem.start(on: context)

            guard let inboxUrl = URL(string: eventItem.url) else {
                let errorMessage = "Unpin: '\(status.stringId() ?? "")' cannot be send to shared inbox url: '\(eventItem.url)'. Incorrect url."

                try? await eventItem.error(errorMessage, on: context)
                context.logger.warning("\(errorMessage)")
                continue
            }

            let shouldSend = await suspendedServersService.shouldSend(to: inboxUrl.host, basedOn: suspendedServers)
            guard shouldSend else {
                try? await eventItem.suspended(on: context)
                context.logger.warning("Sending unpin skipped for suspended host: '\(inboxUrl.host ?? "<unknown>")'.")
                continue
            }

            context.logger.info("[\(index + 1)/\(eventItemsToProceed.count)] Sending unpin: '\(status.stringId() ?? "")' to shared inbox: '\(inboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: inboxUrl.host)
            let requestId = snowflakeService.generate()

            do {
                try await activityPubClient.removeFromFeatured(objectId: status.activityPubId,
                                                               actorId: user.activityPubProfile,
                                                               targetId: featuredCollection,
                                                               on: inboxUrl,
                                                               withId: requestId)

                try? await eventItem.success(on: context)
                try? await suspendedServersService.registerSuccess(for: inboxUrl.host, on: context)
            } catch {
                try? await eventItem.error("\(error)", on: context)
                try? await suspendedServersService.registerConnectionError(for: inboxUrl.host, error: error, on: context)
                context.logger.warning("Sending unpin to shared inbox error. Shared inbox url: \(inboxUrl). Error: \(error).")
            }
        }

        // Mark event as finished successfully.
        let hasFailedEvents = statusActivityPubEvent.statusActivityPubEventItems.contains(where: { $0.isSuccess == false || $0.isSuspended == true })
        try await statusActivityPubEvent.success(result: hasFailedEvents ? .finishedWithErrors : .finished, on: context)
    }

    /// Delivers a private Like or Undo only to the message author's personal inbox.
    /// Retries failed destinations, while skipping successful deliveries and obsolete queued Likes.
    private func sendDirectMessageReaction(event: StatusActivityPubEvent,
                                           status: Status,
                                           favouriteId: String?,
                                           undo: Bool,
                                           on context: ExecutionContext) async throws {
        guard let favouriteId, let sender = try await User.find(event.$user.id, on: context.db), sender.isLocal,
              status.user.isLocal == false,
              try await context.services.statusesService.can(view: status, userId: sender.requireID(), on: context) else {
            try await event.error("Invalid direct-message reaction sender or target.", on: context)

            return
        }

        if undo == false {
            let current = try await StatusFavourite.query(on: context.db)
                .filter(\.$status.$id == status.requireID())
                .filter(\.$user.$id == sender.requireID())
                .first()

            guard current?.stringId() == favouriteId else {
                // The user has already undone this Like. Do not resurrect it after a delayed queue delivery.
                try await event.success(result: .finished, on: context)

                return
            }
        }

        guard let privateKey = sender.privateKey, let inbox = status.user.userInbox,
              let url = URL(string: inbox), url.host != nil,
              ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            try await event.error("Missing private-reaction signing key or recipient inbox.", on: context)

            throw Abort(.internalServerError, reason: "Missing private-reaction signing key or recipient inbox.")
        }

        let suspendedService = context.services.suspendedServersService
        let snapshot = await suspendedService.getSnapshot(on: context)

        for item in event.statusActivityPubEventItems where item.isSuccess != true {
            try await item.start(on: context)

            // Recheck the queued destination: a private reaction may only reach the message author.
            guard item.url == inbox else {
                try await item.error("Destination is not the direct-message author's personal inbox.", on: context)
                continue
            }

            guard await suspendedService.shouldSend(to: url.host, basedOn: snapshot) else {
                try await item.suspended(on: context)
                continue
            }

            let client = ActivityPubClient(privatePemKey: privateKey,
                                           userAgent: Constants.userAgent,
                                           host: url.host,
                                           urlSession: urlSession)

            do {
                let audience = [status.user.activityPubProfile]

                if undo {
                    try await client.unlike(statusFavouriteId: favouriteId,
                                            activityPubStatusId: status.activityPubId,
                                            activityPubProfile: sender.activityPubProfile,
                                            on: url,
                                            recipientActorIds: audience)
                } else {
                    try await client.like(statusFavouriteId: favouriteId,
                                          activityPubStatusId: status.activityPubId,
                                          activityPubProfile: sender.activityPubProfile,
                                          on: url,
                                          recipientActorIds: audience)
                }

                try await item.success(on: context)
                try? await suspendedService.registerSuccess(for: url.host, on: context)
            } catch {
                try await item.error("Private-reaction inbox delivery failed.", on: context)
                try? await suspendedService.registerConnectionError(for: url.host, error: error, on: context)
            }
        }

        let failed = event.statusActivityPubEventItems.contains { $0.isSuccess == false || $0.isSuspended }
        try await event.success(result: failed ? .finishedWithErrors : .finished, on: context)

        if failed {
            throw Abort(.badGateway, reason: "Private-reaction inbox delivery failed.")
        }
    }

    /// Delivers a private Delete only to the original explicit remote recipients, using their personal inboxes.
    /// Errors propagate to StatusDeleterJob so its existing retry policy can retry delivery.
    private func deleteDirectMessage(_ message: DeletedDirectMessage, userId: Int64, on context: ExecutionContext) async throws {
        guard message.$author.id == userId else {
            throw Abort(.forbidden, reason: "Only the direct-message author may federate its deletion.")
        }

        let audience = try await DeletedDirectMessageRecipient.query(on: context.db)
            .filter(\.$message.$id == message.requireID())
            .with(\.$user)
            .all()

        // Deletion markers retain the original audience after Status and its recipient rows have been removed.
        let actorIds = audience.map { $0.user.activityPubProfile }
        let remoteRecipients = audience.map(\.user).filter { $0.isLocal == false }

        guard remoteRecipients.isEmpty == false else {
            return
        }

        guard let user = try await User.query(on: context.db)
            .withDeleted()
            .filter(\.$id == userId)
            .first(),
              user.isLocal, let privateKey = user.privateKey else {
            throw Abort(.internalServerError, reason: "Missing direct-message sender or signing key.")
        }

        var deliveredInboxes: Set<String> = []
        var hasFailures = false

        for recipient in remoteRecipients {
            guard let inbox = recipient.userInbox, let url = URL(string: inbox), url.host != nil,
                  ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
                hasFailures = true
                continue
            }

            guard deliveredInboxes.insert(inbox).inserted else {
                continue
            }

            let client = ActivityPubClient(privatePemKey: privateKey,
                                           userAgent: Constants.userAgent,
                                           host: url.host,
                                           urlSession: urlSession)

            do {
                try await client.delete(actorId: user.activityPubProfile,
                                        statusId: message.activityPubId,
                                        on: url,
                                        recipientActorIds: actorIds)
            } catch {
                // Continue with the other recipients before asking the queue to retry this idempotent Delete.
                hasFailures = true
                context.logger.warning("Direct-message Delete delivery failed for inbox: '\(inbox)'.")
            }
        }

        if hasFailures {
            throw Abort(.badGateway, reason: "Direct-message Delete failed for one or more inboxes.")
        }
    }

    private func getStatus(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws -> Status? {
        let statusesService = context.services.statusesService
        let operation = statusActivityPubEvent.type

        guard let status = try await statusesService.get(id: statusActivityPubEvent.status.requireID(), on: context.db) else {
            let errorMessage = "Status \(operation): '\(statusActivityPubEvent.$status.id)' cannot be downloaded from database."

            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return nil
        }

        return status
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

    private func getPrivateKey(statusActivityPubEvent: StatusActivityPubEvent, on context: ExecutionContext) async throws -> String? {
        let user = statusActivityPubEvent.user
        let status = statusActivityPubEvent.status
        let operation = statusActivityPubEvent.type

        guard let privateKey = try await User.query(on: context.application.db).filter(\.$id == user.requireID()).first()?.privateKey else {
            let errorMessage = "Status \(operation): '\(status.stringId() ?? "")' cannot be send to shared inbox. Missing private key for user '\(status.user.stringId() ?? "")'."

            // Mark event as finished with error.
            try await statusActivityPubEvent.error(errorMessage, on: context)

            context.logger.warning("\(errorMessage)")
            return nil
        }

        return privateKey
    }
}
