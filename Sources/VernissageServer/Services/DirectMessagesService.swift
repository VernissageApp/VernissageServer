//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import FluentSQL
import SQLKit
import SwiftSoup
import Vapor
import Queues

extension Application.Services {
    struct DirectMessagesServiceKey: StorageKey {
        typealias Value = DirectMessagesServiceType
    }

    var directMessagesService: DirectMessagesServiceType {
        get {
            self.application.storage[DirectMessagesServiceKey.self] ?? DirectMessagesService()
        }
        nonmutating set {
            self.application.storage[DirectMessagesServiceKey.self] = newValue
        }
    }
}

/// Shared direct-message operations for authenticated controllers and future ActivityPub handlers.
protocol DirectMessagesServiceType: Sendable {

    /// Returns the viewer's inbox ordered by local activity, with bounded pagination.
    func list(userId: Int64, page: Int, size: Int, on context: ExecutionContext) async throws -> PaginableResultDto<DirectConversationDto>

    /// Counts conversations containing unread incoming messages, including muted conversations.
    func unreadCount(userId: Int64, on context: ExecutionContext) async throws -> Int

    /// Returns a personalized conversation or a non-disclosing not-found error.
    func conversation(id: Int64, userId: Int64, on context: ExecutionContext) async throws -> DirectConversationDto

    /// Lists only messages authored by or explicitly addressed to the viewer, newest first.
    func messages(conversationId: Int64, userId: Int64, page: Int, size: Int, on context: ExecutionContext) async throws -> PaginableResultDto<DirectMessageDto>

    /// Creates a local message and atomically records recipients, local inboxes and remote delivery events.
    func create(basedOn dto: DirectMessageRequestDto, conversationId: Int64?, userId: Int64, on context: ExecutionContext) async throws -> DirectMessageDto

    /// Dispatches pushes for notifications created by store, using a context outside its transaction.
    func dispatchNotifications(_ notifications: [Notification], on context: ExecutionContext) async

    /// Marks only selected, accessible messages as read; concurrent messages are unaffected.
    func markRead(conversationId: Int64, statusIds: [String], userId: Int64, on context: ExecutionContext) async throws

    /// Changes notification preference without marking messages read or moving the conversation.
    func mute(conversationId: Int64, userId: Int64, isMuted: Bool, on context: ExecutionContext) async throws

    /// Saves content-free metadata and explicit recipients before status deletion, inside the caller's transaction.
    /// Clears affected previews without changing inbox activity, read time or mute preference.
    func preserveDeletedMessage(status: Status, conversationId: Int64, on context: ExecutionContext) async throws

    /// Refreshes previews showing this edited message, without changing activity order or read state.
    /// The caller must use the same transaction that updates the message.
    func refreshPreview(status: Status, on context: ExecutionContext) async throws

    /// Removes a deleted account's message markers and addressing, then rebuilds surviving inboxes.
    /// Call after deleting the author's statuses, before physically deleting the account.
    /// Conversations with at most one remaining participant are removed with their messages.
    func removeAccount(userId: Int64, on context: ExecutionContext) async throws

    /// Filters local recipients against the author and the original audience of this message.
    /// A recipient's block excludes only that recipient; remote servers enforce their own users' blocks.
    func eligibleRecipientIds(authorId: Int64, recipientIds: [Int64], on context: ExecutionContext) async throws -> Set<Int64>

    /// Persists a prepared mentioned status and explicit recipients in an existing transaction.
    /// Returns notifications saved in that transaction; dispatch them only after its outermost commit.
    /// The ActivityPub caller must authenticate its actor and normalize addressing before calling this method.
    /// Repeated delivery of the same object does not recreate unread messages or move the inbox.
    func store(status: Status, recipientIds: [Int64], conversationId: Int64?, on context: ExecutionContext) async throws -> DirectMessageStoreResult
}

/// Keeps inbox membership separate from per-message access and read state.
final class DirectMessagesService: DirectMessagesServiceType {
    public func list(userId: Int64, page: Int, size: Int, on context: ExecutionContext) async throws -> PaginableResultDto<DirectConversationDto> {
        try validatePagination(page: page, size: size)

        let result = try await UserDirectConversation.query(on: context.db)
            .filter(\.$user.$id == userId)
            .sort(\.$lastActivityAt, .descending)
            .sort(\.$id, .descending)
            .paginate(PageRequest(page: page, per: size))

        var data: [DirectConversationDto] = []

        for inbox in result.items {
            data.append(try await convert(inbox: inbox, on: context))
        }

        return PaginableResultDto(data: data, page: result.metadata.page, size: result.metadata.per, total: result.metadata.total)
    }

    public func unreadCount(userId: Int64, on context: ExecutionContext) async throws -> Int {
        try await UserDirectConversation.query(on: context.db)
            .filter(\.$user.$id == userId)
            .filter(.sql(embed: unreadCondition(userId: userId)))
            .count()
    }

    public func conversation(id: Int64, userId: Int64, on context: ExecutionContext) async throws -> DirectConversationDto {
        try await convert(inbox: inbox(conversationId: id, userId: userId, on: context.db), on: context)
    }

    public func messages(conversationId: Int64, userId: Int64, page: Int, size: Int, on context: ExecutionContext) async throws -> PaginableResultDto<DirectMessageDto> {
        try validatePagination(page: page, size: size)
        _ = try await inbox(conversationId: conversationId, userId: userId, on: context.db)

        guard let sql = context.db as? SQLDatabase else {
            throw Abort(.internalServerError, reason: "Direct-message pagination requires SQL.")
        }

        // One ordered page spans live statuses and deleted-message markers, using the original status ids.
        let selection = messageSelection(conversationId: conversationId, userId: userId)
        let totalRow = try await sql.raw("SELECT COUNT(*) AS total FROM (\(selection)) AS messages").first()
        let total = try totalRow?.decode(column: "total", as: Int.self) ?? 0
        let rows = try await sql.raw("""
            SELECT id FROM (\(selection)) AS messages ORDER BY id DESC
            LIMIT \(bind: size) OFFSET \(bind: (page - 1) * size)
            """).all()

        var data: [DirectMessageDto] = []

        for row in rows {
            let id = try row.decode(column: "id", as: Int64.self)

            if let deleted = try await visibleDeletedMessages(conversationId: conversationId, userId: userId, on: context.db)
                .filter(\.$id == id)
                .first() {
                data.append(try await deletedMessageDto(deleted, on: context))
            } else {
                data.append(try await messageDto(statusId: id, userId: userId, on: context))
            }
        }

        return PaginableResultDto(data: data, page: page, size: size, total: total)
    }

    public func create(basedOn dto: DirectMessageRequestDto, conversationId: Int64?, userId: Int64, on context: ExecutionContext) async throws -> DirectMessageDto {
        guard dto.recipientIds.count <= 100 else {
            throw DirectMessageError.recipientsRequired
        }

        let recipients = Array(Set(try ids(dto.recipientIds))).filter { $0 != userId }.sorted()

        guard (1...100).contains(recipients.count) else {
            throw DirectMessageError.recipientsRequired
        }

        let attachmentIds = try ids(dto.attachmentIds)

        guard Set(attachmentIds).count == attachmentIds.count else {
            throw StatusError.incorrectAttachmentId
        }

        guard dto.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || attachmentIds.isEmpty == false else {
            throw DirectMessageError.emptyMessage
        }

        guard dto.note.count <= (context.settings.cached?.maxCharacters ?? Constants.statusMaxCharacters) else {
            throw DirectMessageError.messageTooLong
        }

        guard attachmentIds.count <= (context.settings.cached?.maxMediaAttachments ?? Constants.statusMaxMediaAttachments) else {
            throw StatusError.maxLimitOfAttachmentsExceeded
        }

        let replyId = try dto.replyToStatusId.map { try ids([$0])[0] }

        if conversationId == nil, replyId != nil {
            throw DirectMessageError.invalidReply
        }

        let result = try await context.db.transaction { database in
            let transactionalContext = context.with(transaction: database)

            // Acquire the first write before reading: SQLite read transactions cannot safely upgrade
            // under a competing writer. PostgreSQL serializes existing conversation writers on this row.
            let targetConversationId: Int64

            if let conversationId {
                try await self.lockConversation(id: conversationId, on: database)
                targetConversationId = conversationId
            } else {
                let conversation = DirectConversation(id: context.services.snowflakeService.generate())

                try await conversation.create(on: database)
                targetConversationId = try conversation.requireID()
            }

            guard let author = try await User.find(userId, on: database) else {
                throw EntityNotFoundError.userNotFound
            }

            guard author.isLocal, author.isBlocked == false, author.isApproved else {
                throw DirectMessageError.recipientUnavailable
            }

            guard author.emailWasConfirmed == true else {
                throw StatusError.emailNotVerified
            }

            guard author.$movedTo.id == nil else {
                throw StatusError.accountHasBeenMoved
            }

            if let conversationId {
                _ = try await self.inbox(conversationId: conversationId, userId: userId, on: database)
            }

            for id in recipients {
                guard let user = try await User.find(id, on: database), user.isBlocked == false,
                      user.isSuppressed == false, user.$movedTo.id == nil else {
                    throw DirectMessageError.recipientUnavailable
                }

                let blocks = try await UserBlockedUser.query(on: database)
                    .filter(\.$user.$id == userId)
                    .filter(\.$blockedUser.$id == id)
                    .count()

                // The author cannot explicitly address someone they block. Recipient-owned blocks
                // are applied independently by store, so other recipients can still receive the message.
                guard blocks == 0 else {
                    throw DirectMessageError.recipientUnavailable
                }
            }

            var parent: Status?
            var deletedParent: DeletedDirectMessage?

            if let replyId, let conversationId {
                parent = try await self.visibleStatuses(conversationId: conversationId, userId: userId, on: database)
                    .filter(\.$id == replyId)
                    .first()
                deletedParent = try await self.visibleDeletedMessages(conversationId: conversationId, userId: userId, on: database)
                    .filter(\.$id == replyId)
                    .first()

                guard parent != nil || deletedParent != nil else {
                    throw DirectMessageError.invalidReply
                }
            } else if let conversationId {
                // Federation needs a parent even when the client sends a reply without selecting one.
                // Only use a message visible to this author, including content-free deletion markers.
                parent = try await self.visibleStatuses(conversationId: conversationId, userId: userId, on: database)
                    .sort(\.$id, .descending)
                    .first()
                deletedParent = try await self.visibleDeletedMessages(conversationId: conversationId, userId: userId, on: database)
                    .sort(\.$id, .descending)
                    .first()

                if let liveId = parent?.id, let deletedId = deletedParent?.id, liveId > deletedId {
                    deletedParent = nil
                } else if deletedParent != nil {
                    parent = nil
                }
            }

            let newStatusId = context.services.snowflakeService.generate()
            let status = Status(id: newStatusId,
                                userId: userId,
                                note: dto.note,
                                baseAddress: context.settings.cached?.baseAddress ?? "",
                                userName: author.userName,
                                application: context.request?.applicationName,
                                categoryId: nil,
                                visibility: .mentioned,
                                replyToStatusId: parent?.id,
                                publishedAt: Date())

            status.replyToActivityPubId = parent?.activityPubId ?? deletedParent?.activityPubId

            try await status.create(on: database)

            // Reserve attachments in id order to avoid concurrent reuse and lock-order deadlocks.
            for id in attachmentIds.sorted() {
                try await Attachment.query(on: database)
                    .filter(\.$id == id)
                    .filter(\.$user.$id == userId)
                    .set(\.$updatedAt, to: Date())
                    .update()

                guard let attachment = try await Attachment.query(on: database)
                    .filter(\.$id == id)
                    .filter(\.$user.$id == userId)
                    .filter(\.$status.$id == nil)
                    .first() else {
                    throw EntityNotFoundError.attachmentNotFound
                }

                // Connection is established after the status insert, still in the same transaction.
                attachment.$status.id = status.id
                attachment.order = attachmentIds.firstIndex(of: id) ?? 0
                try await attachment.save(on: database)
            }

            let saved = try await self.store(status: status,
                                             recipientIds: recipients,
                                             conversationId: targetConversationId,
                                             on: transactionalContext)

            let delivery = try await self.prepareDelivery(status: saved.status, on: transactionalContext)

            return (message: saved, delivery: delivery)
        }

        await dispatchNotifications(result.message.notifications, on: context)

        if let delivery = result.delivery {
            do {
                try await context.queues(.apStatus).dispatch(ActivityPubStatusJob.self, delivery, maxRetryCount: 3)
            } catch {
                // The committed waiting event is picked up by RescheduleActivityPubJob.
                context.logger.warning("Could not enqueue direct-message delivery event: '\(delivery.statusActivityPubEventId)'.")
            }
        }

        return try await messageDto(statusId: result.message.status.requireID(), userId: userId, on: context)
    }

    public func store(status: Status,
                      recipientIds: [Int64],
                      conversationId: Int64?,
                      on context: ExecutionContext) async throws -> DirectMessageStoreResult {
        guard status.visibility == .mentioned else {
            throw DirectMessageError.invalidReply
        }

        // A repeated delivery must preserve read state and must not create another notification.
        if let existing = try await Status.query(on: context.db)
            .filter(\.$activityPubId == status.activityPubId)
            .first(),
           existing.$directConversation.id != nil {
            return DirectMessageStoreResult(status: existing, notifications: [])
        }

        guard try await DeletedDirectMessage.query(on: context.db)
            .filter(\.$activityPubId == status.activityPubId)
            .first() == nil else {
            throw DirectMessageError.messageNotFound
        }

        // Evaluate every recipient against the same original audience, before removing anyone from it.
        let authorId = status.$user.id
        let recipientIds = try await eligibleRecipientIds(authorId: authorId, recipientIds: recipientIds, on: context)

        guard recipientIds.isEmpty == false else {
            throw DirectMessageError.recipientUnavailable
        }

        let conversation: DirectConversation

        if let conversationId {
            guard let existing = try await DirectConversation.find(conversationId, on: context.db) else {
                throw DirectMessageError.conversationNotFound
            }

            conversation = existing
            try await lockConversation(id: conversationId, on: context.db)
        } else {
            conversation = DirectConversation(id: context.services.snowflakeService.generate())
            try await conversation.create(on: context.db)
        }

        let conversationId = try conversation.requireID()
        status.$directConversation.id = conversationId
        try await status.save(on: context.db)

        // An unresolved remote parent still makes this message a reply, rather than a conversation root.
        if conversation.$rootStatus.id == nil, status.$replyToStatus.id == nil, status.replyToActivityPubId == nil {
            conversation.$rootStatus.id = status.id
            try await conversation.save(on: context.db)
        }

        for id in recipientIds.sorted() {
            let newStatusRecipientId = context.services.snowflakeService.generate()
            let recipient = StatusRecipient(id: newStatusRecipientId,
                                            statusId: try status.requireID(),
                                            userId: id)

            try await recipient.create(on: context.db)
        }

        // Only local users have inbox entries. Remote recipients remain stored for later delivery.
        let localUsers = try await User.query(on: context.db)
            .filter(\.$id ~~ Array(recipientIds.union([authorId])))
            .filter(\.$isLocal == true)
            .all()

        let summary = try await messageSummary(status: status, on: context)

        // Inbox order follows local arrival time, so a delayed remote message also moves its conversation to the top.
        let now = Date()

        var notifications: [Notification] = []

        for user in localUsers {
            let userId = try user.requireID()
            let entry = try await UserDirectConversation.query(on: context.db)
                .filter(\.$user.$id == userId)
                .filter(\.$conversation.$id == conversationId)
                .first()
                ?? UserDirectConversation(id: context.services.snowflakeService.generate(),
                                          userId: userId,
                                          conversationId: conversationId,
                                          lastActivityAt: now)

            entry.$lastStatus.id = status.id
            entry.summary = summary
            entry.lastActivityAt = now
            try await entry.save(on: context.db)

            // A muted conversation still receives messages and unread state, but no notification or push.
            let notificationsService = context.services.notificationsService
            if userId != authorId, entry.isMuted == false,
               let notification = try await notificationsService.createStored(
                   type: .directMessage,
                   to: user,
                   by: authorId,
                   statusId: status.requireID(),
                   mainStatusId: nil, on: context) {
                notifications.append(notification)
            }
        }

        return DirectMessageStoreResult(status: status, notifications: notifications)
    }

    public func markRead(conversationId: Int64, statusIds: [String], userId: Int64, on context: ExecutionContext) async throws {
        guard (1...100).contains(statusIds.count) else {
            throw DirectMessageError.invalidReadSelection
        }

        let statusIds = Array(Set(try ids(statusIds)))

        try await context.db.transaction { database in
            try await self.lockConversation(id: conversationId, on: database)
            _ = try await self.inbox(conversationId: conversationId, userId: userId, on: database)

            let liveCount = try await self.visibleStatuses(conversationId: conversationId, userId: userId, on: database)
                .filter(\.$id ~~ statusIds)
                .count()

            let deletedCount = try await self.visibleDeletedMessages(conversationId: conversationId, userId: userId, on: database)
                .filter(\.$id ~~ statusIds)
                .count()

            // Validate the whole selection before writing, deleted placeholders remain valid selections.
            guard liveCount + deletedCount == statusIds.count else {
                throw DirectMessageError.invalidReadSelection
            }

            let now = Date()

            // Mark only displayed incoming messages, retries preserve read times and later arrivals stay unread.
            try await StatusRecipient.query(on: database)
                .filter(\.$user.$id == userId)
                .filter(\.$status.$id ~~ statusIds)
                .filter(\.$readAt == nil)
                .set(\.$readAt, to: now)
                .update()

            // Updating only this field preserves a concurrently updated preview, activity date or mute flag.
            try await UserDirectConversation.query(on: database)
                .filter(\.$user.$id == userId)
                .filter(\.$conversation.$id == conversationId)
                .set(\.$lastReadAt, to: now)
                .update()
        }
    }

    public func mute(conversationId: Int64, userId: Int64, isMuted: Bool, on context: ExecutionContext) async throws {
        _ = try await inbox(conversationId: conversationId, userId: userId, on: context.db)

        try await UserDirectConversation.query(on: context.db)
            .filter(\.$user.$id == userId)
            .filter(\.$conversation.$id == conversationId)
            .set(\.$isMuted, to: isMuted)
            .update()
    }

    /// Dispatches pushes after commit. A queue failure must not turn a persisted message into a failed send response.
    public func dispatchNotifications(_ notifications: [Notification], on context: ExecutionContext) async {
        for notification in notifications {
            do {
                try await context.services.notificationsService.sendWebPushes(for: [notification], on: context)
            } catch {
                context.logger.error("[DirectMessages] Could not enqueue notification pushes: \(error)")
            }
        }
    }

    public func preserveDeletedMessage(status: Status, conversationId: Int64, on context: ExecutionContext) async throws {
        try await lockConversation(id: conversationId, on: context.db)
        let statusId = try status.requireID()
        let deleted = try DeletedDirectMessage(status: status, conversationId: conversationId)

        // A deleted parent has no Status row, so retain its placeholder id for the client's reply link.
        if deleted.replyToStatusId == nil, let parentActivityPubId = status.replyToActivityPubId {
            deleted.replyToStatusId = try await DeletedDirectMessage.query(on: context.db)
                .filter(\.$conversation.$id == conversationId)
                .filter(\.$activityPubId == parentActivityPubId)
                .first()?.id
        }

        try await deleted.create(on: context.db)

        let recipients = try await StatusRecipient.query(on: context.db)
            .filter(\.$status.$id == statusId)
            .all()

        for recipient in recipients {
            let preserved = DeletedDirectMessageRecipient(id: context.services.snowflakeService.generate(),
                messageId: statusId, userId: recipient.$user.id)
            try await preserved.create(on: context.db)
        }

        // Only previews that currently show this message are cleared. Deletion is not new conversation activity.
        try await UserDirectConversation.query(on: context.db)
            .filter(\.$conversation.$id == conversationId)
            .filter(\.$lastStatus.$id == statusId)
            .set(\.$summary, to: nil)
            .update()
    }

    public func refreshPreview(status: Status, on context: ExecutionContext) async throws {
        guard let conversationId = status.$directConversation.id else {
            throw DirectMessageError.conversationNotFound
        }

        let summary = try await messageSummary(status: status, on: context)

        // Other participants may have a different last visible message; their previews must remain unchanged.
        try await UserDirectConversation.query(on: context.db)
            .filter(\.$conversation.$id == conversationId)
            .filter(\.$lastStatus.$id == status.requireID())
            .set(\.$summary, to: summary)
            .update()
    }

    public func eligibleRecipientIds(authorId: Int64, recipientIds: [Int64], on context: ExecutionContext) async throws -> Set<Int64> {
        guard let author = try await User.find(authorId, on: context.db) else {
            throw EntityNotFoundError.userNotFound
        }

        let recipients = Set(recipientIds).subtracting([authorId])
        let participants = recipients.union([authorId])
        let localRecipients = try await User.query(on: context.db)
            .filter(\.$id ~~ Array(recipients))
            .filter(\.$isLocal == true)
            .all()
        let localIds = localRecipients.compactMap { $0.id }

        // Recipient-to-recipient blocks are directional: do not exclude the person being blocked.
        // Keep the existing rule that a block in either direction between author and recipient prevents delivery.
        let blocks = try await UserBlockedUser.query(on: context.db)
            .group(.or) { group in
                group.group(.and) {
                    $0.filter(\.$user.$id ~~ localIds)
                        .filter(\.$blockedUser.$id ~~ Array(participants))
                }

                group.group(.and) {
                    $0.filter(\.$user.$id == authorId)
                        .filter(\.$blockedUser.$id ~~ localIds)
                }
            }
            .all()

        var eligible = recipients

        for recipient in localRecipients {
            let recipientId = try recipient.requireID()
            let isBlocked = blocks.contains {
                ($0.$user.id == recipientId && $0.$blockedUser.id != recipientId)
                    || ($0.$user.id == authorId && $0.$blockedUser.id == recipientId)
            }
            let domainBlocked = try await context.services.userBlockedDomainsService.isDomainBlockedByUser(
                userId: recipientId,
                actorId: author.activityPubProfile,
                on: context)

            if recipient.isBlocked || recipient.isSuppressed || recipient.isApproved == false || isBlocked || domainBlocked {
                eligible.remove(recipientId)
            }
        }

        return eligible
    }

    public func removeAccount(userId: Int64, on context: ExecutionContext) async throws {
        let inboxes = try await UserDirectConversation.query(on: context.db)
            .filter(\.$user.$id == userId)
            .all()
        let authoredMarkers = try await DeletedDirectMessage.query(on: context.db)
            .filter(\.$author.$id == userId)
            .all()
        let recipients = try await StatusRecipient.query(on: context.db)
            .filter(\.$user.$id == userId)
            .with(\.$status)
            .all()
        let deletedRecipients = try await DeletedDirectMessageRecipient.query(on: context.db)
            .filter(\.$user.$id == userId)
            .with(\.$message)
            .all()

        // Remote users have no inbox entries; their participation is recorded in message audiences.
        let conversationIds = Set(inboxes.map { $0.$conversation.id })
            .union(authoredMarkers.map { $0.$conversation.id })
            .union(recipients.compactMap { $0.status.$directConversation.id })
            .union(deletedRecipients.map { $0.message.$conversation.id })

        for conversationId in conversationIds.sorted() {
            try await context.db.transaction { database in
                let transactionContext = context.with(transaction: database)
                try await self.removeAccount(userId: userId, conversationId: conversationId, on: transactionContext)
            }
        }

        try await DirectMessageLikeReceipt.query(on: context.db)
            .filter(\.$user.$id == userId)
            .delete()
    }

    /// Count the original audience before removing markers, including remote recipients without inboxes.
    private func removeAccount(userId: Int64, conversationId: Int64, on context: ExecutionContext) async throws {
        try await lockConversation(id: conversationId, on: context.db)

        let statuses = try await Status.query(on: context.db)
            .filter(\.$directConversation.$id == conversationId)
            .with(\.$recipients)
            .all()
        let markers = try await DeletedDirectMessage.query(on: context.db)
            .filter(\.$conversation.$id == conversationId)
            .with(\.$recipients)
            .all()
        let inboxes = try await UserDirectConversation.query(on: context.db)
            .filter(\.$conversation.$id == conversationId)
            .all()

        let participantIds = Set(statuses.map { $0.$user.id })
            .union(statuses.flatMap { $0.recipients.map { $0.$user.id } })
            .union(markers.map { $0.$author.id })
            .union(markers.flatMap { $0.recipients.map { $0.$user.id } })
            .union(inboxes.map { $0.$user.id })
            .subtracting([userId])

        let remainingParticipants = try await User.query(on: context.db)
            .filter(\.$id ~~ Array(participantIds))
            .count()

        if remainingParticipants <= 1 {
            // Use normal status cleanup so attachment files and all dependent rows are handled too.
            for status in statuses {
                try await context.services.statusesService.delete(id: status.requireID(), on: context)
            }

            try await DirectConversation.query(on: context.db)
                .filter(\.$id == conversationId)
                .delete()

            return
        }

        try await DeletedDirectMessage.query(on: context.db)
            .filter(\.$conversation.$id == conversationId)
            .filter(\.$author.$id == userId)
            .delete()

        try await StatusRecipient.query(on: context.db)
            .filter(\.$status.$id ~~ statuses.compactMap { $0.id })
            .filter(\.$user.$id == userId)
            .delete()
        try await DeletedDirectMessageRecipient.query(on: context.db)
            .filter(\.$message.$id ~~ markers.compactMap { $0.id })
            .filter(\.$user.$id == userId)
            .delete()
        try await UserDirectConversation.query(on: context.db)
            .filter(\.$conversation.$id == conversationId)
            .filter(\.$user.$id == userId)
            .delete()

        // Removed parents must not leave links to placeholders that no longer exist.
        let removedMarkerIds = markers.filter { $0.$author.id == userId }.compactMap { $0.id }
        try await DeletedDirectMessage.query(on: context.db)
            .filter(\.$conversation.$id == conversationId)
            .filter(\.$replyToStatusId ~~ removedMarkerIds)
            .set(\.$replyToStatusId, to: nil)
            .update()

        for inbox in inboxes where inbox.$user.id != userId {
            try await rebuildInbox(inbox, on: context)
        }
    }

    /// Rebuild previews from this viewer's audience, preserving read receipts and mute preferences.
    private func rebuildInbox(_ inbox: UserDirectConversation, on context: ExecutionContext) async throws {
        let status = try await visibleStatuses(conversationId: inbox.$conversation.id, userId: inbox.$user.id, on: context.db)
            .sort(\.$id, .descending)
            .first()
        let marker = try await visibleDeletedMessages(conversationId: inbox.$conversation.id, userId: inbox.$user.id, on: context.db)
            .sort(\.$id, .descending)
            .first()

        if let status, (status.id ?? 0) > (marker?.id ?? 0) {
            inbox.$lastStatus.id = status.id
            inbox.summary = try await messageSummary(status: status, on: context)
            inbox.lastActivityAt = status.createdAt ?? status.publishedAt ?? inbox.lastActivityAt
        } else if let marker {
            inbox.$lastStatus.id = nil
            inbox.summary = nil
            inbox.lastActivityAt = marker.publishedAt
        } else {
            // A participant may have no remaining visible messages in a surviving group conversation.
            inbox.$lastStatus.id = nil
            inbox.summary = nil
        }

        try await inbox.save(on: context.db)
    }

    private func messageSummary(status: Status, on context: ExecutionContext) async throws -> String {
        let hasAttachments = try await Attachment.query(on: context.db)
            .filter(\.$status.$id == status.requireID())
            .count() > 0

        // Local notes are plain text, while remote notes contain HTML; normalize both before building the preview.
        let html = status.isLocal ? (status.note ?? "").html(baseAddress: "", wrapInParagraph: true) : (status.note ?? "")
        let text = try SwiftSoup.parse(html).text().trimmingCharacters(in: .whitespacesAndNewlines)

        return String((text.isEmpty && hasAttachments ? "Image" : text).prefix(200))
    }

    private func validatePagination(page: Int, size: Int) throws {
        guard page > 0, (1...100).contains(size) else {
            throw DirectMessageError.invalidPagination
        }
    }

    /// SQL EXISTS avoids duplicated messages when the author has several recipients.
    private func visibility(userId: Int64) -> SQLQueryString {
        """
        (\(ident: Status.schema).\(ident: "userId") = \(bind: userId) OR EXISTS (
            SELECT 1 FROM \(ident: StatusRecipient.schema) AS r
            WHERE r.\(ident: "statusId") = \(ident: Status.schema).\(ident: "id")
              AND r.\(ident: "userId") = \(bind: userId)
        ))
        """
    }

    private func visibleStatuses(conversationId: Int64, userId: Int64, on database: Database) -> QueryBuilder<Status> {
        Status.query(on: database)
            .filter(\.$directConversation.$id == conversationId)
            .filter(\.$visibility == .mentioned)
            .filter(.sql(embed: visibility(userId: userId)))
    }

    // lastReadAt describes inbox activity; only recipient readAt values determine whether messages are unread.
    private func unreadCondition(userId: Int64) -> SQLQueryString {
        """
        EXISTS (SELECT 1 FROM \(ident: StatusRecipient.schema) AS r
            INNER JOIN \(ident: Status.schema) AS s ON s.\(ident: "id") = r.\(ident: "statusId")
            WHERE s.\(ident: "directConversationId") = \(ident: UserDirectConversation.schema).\(ident: "conversationId")
              AND s.\(ident: "visibility") = \(bind: StatusVisibility.mentioned.rawValue)
              AND s.\(ident: "userId") <> \(bind: userId)
              AND r.\(ident: "userId") = \(bind: userId) AND r.\(ident: "readAt") IS NULL)
        """
    }

    /// Inbox ownership is required for every conversation action; knowing an id grants no access.
    private func inbox(conversationId: Int64, userId: Int64, on database: Database) async throws -> UserDirectConversation {
        guard let inbox = try await UserDirectConversation.query(on: database)
            .filter(\.$conversation.$id == conversationId)
            .filter(\.$user.$id == userId)
            .first() else {
            throw DirectMessageError.conversationNotFound
        }

        return inbox
    }

    /// Participants are collected only from visible messages, never from the entire conversation.
    private func convert(inbox: UserDirectConversation, on context: ExecutionContext) async throws -> DirectConversationDto {
        let userId = inbox.$user.id
        let conversationId = inbox.$conversation.id

        let audience: SQLQueryString = """
        \(ident: User.schema).\(ident: "id") IN (
            SELECT \(ident: Status.schema).\(ident: "userId") FROM \(ident: Status.schema)
            WHERE \(ident: "directConversationId") = \(bind: conversationId) AND \(visibility(userId: userId))
            UNION
            SELECT r.\(ident: "userId") FROM \(ident: StatusRecipient.schema) AS r
            INNER JOIN \(ident: Status.schema) ON \(ident: Status.schema).\(ident: "id") = r.\(ident: "statusId")
            WHERE \(ident: Status.schema).\(ident: "directConversationId") = \(bind: conversationId) AND \(visibility(userId: userId))
            UNION
            SELECT \(ident: DeletedDirectMessage.schema).\(ident: "authorId") FROM \(ident: DeletedDirectMessage.schema)
            WHERE \(ident: "conversationId") = \(bind: conversationId) AND \(deletedVisibility(userId: userId))
            UNION
            SELECT r.\(ident: "userId") FROM \(ident: DeletedDirectMessageRecipient.schema) AS r
            INNER JOIN \(ident: DeletedDirectMessage.schema) ON \(ident: DeletedDirectMessage.schema).\(ident: "id") = r.\(ident: "messageId")
            WHERE \(ident: "conversationId") = \(bind: conversationId) AND \(deletedVisibility(userId: userId))
        )
        """

        let users = try await User.query(on: context.db)
            .filter(.sql(embed: audience))
            .sort(\.$id)
            .all()

        let unread = try await UserDirectConversation.query(on: context.db)
            .filter(\.$id == inbox.requireID())
            .filter(.sql(embed: unreadCondition(userId: userId)))
            .count() > 0

        // Deleting the last status clears its foreign key, use its marker to keep the deleted preview identifiable.
        let lastDeleted = inbox.$lastStatus.id == nil
            ? try await visibleDeletedMessages(conversationId: conversationId, userId: userId, on: context.db)
                .sort(\.$id, .descending)
                .first()
            : nil

        return DirectConversationDto(id: String(conversationId), participants: users.map { userDto($0, on: context) },
                                     lastStatusId: (inbox.$lastStatus.id ?? lastDeleted?.id).map(String.init), summary: inbox.summary,
                                     lastActivityAt: inbox.lastActivityAt, lastReadAt: inbox.lastReadAt,
                                     hasUnreadMessages: unread, isMuted: inbox.isMuted, lastMessageDeletedAt: lastDeleted?.deletedAt)
    }

    private func userDto(_ user: User, on context: ExecutionContext) -> UserDto {
        UserDto(from: user,
                baseImagesPath: context.services.storageService.getBaseImagesPath(on: context),
                baseAddress: context.settings.cached?.baseAddress ?? "")
    }

    private func messageDto(statusId: Int64, userId: Int64, on context: ExecutionContext) async throws -> DirectMessageDto {
        let statusesService = context.services.statusesService
        
        guard let status = try await statusesService.get(id: statusId, on: context.db),
              let conversationId = status.$directConversation.id else {
            throw DirectMessageError.messageNotFound
        }

        let recipients = try await StatusRecipient.query(on: context.db)
            .with(\.$user)
            .filter(\.$status.$id == statusId)
            .sort(\.$user.$id)
            .all()

        let dto = await statusesService.convertToDto(status: status,
                                                     attachments: status.attachments,
                                                     attachUserInteractions: true,
                                                     on: context)

        var deletedParent: DeletedDirectMessage?

        if let activityPubId = status.replyToActivityPubId {
            deletedParent = try await visibleDeletedMessages(conversationId: conversationId, userId: userId, on: context.db)
                .filter(\.$activityPubId == activityPubId)
                .first()
        }

        return DirectMessageDto(id: String(statusId),
                                conversationId: String(conversationId),
                                status: dto,
                                recipients: recipients.map { userDto($0.user, on: context) },
                                readAt: recipients.first { $0.$user.id == userId }?.readAt,
                                author: userDto(status.user, on: context),
                                publishedAt: status.publishedAt,
                                replyToStatusId: (status.$replyToStatus.id ?? deletedParent?.id).map(String.init))
    }

    private func deletedVisibility(userId: Int64) -> SQLQueryString {
        """
        (\(ident: DeletedDirectMessage.schema).\(ident: "authorId") = \(bind: userId) OR EXISTS (
            SELECT 1 FROM \(ident: DeletedDirectMessageRecipient.schema) AS audience
            WHERE audience.\(ident: "messageId") = \(ident: DeletedDirectMessage.schema).\(ident: "id")
              AND audience.\(ident: "userId") = \(bind: userId)
        ))
        """
    }

    private func visibleDeletedMessages(conversationId: Int64, userId: Int64, on database: Database) -> QueryBuilder<DeletedDirectMessage> {
        DeletedDirectMessage.query(on: database)
            .filter(\.$conversation.$id == conversationId)
            .filter(.sql(embed: deletedVisibility(userId: userId)))
    }

    private func messageSelection(conversationId: Int64, userId: Int64) -> SQLQueryString {
        """
        SELECT \(ident: "id") FROM \(ident: Status.schema)
        WHERE \(ident: "directConversationId") = \(bind: conversationId)
          AND \(ident: "visibility") = \(bind: StatusVisibility.mentioned.rawValue) AND \(visibility(userId: userId))
        UNION ALL
        SELECT \(ident: "id") FROM \(ident: DeletedDirectMessage.schema)
        WHERE \(ident: "conversationId") = \(bind: conversationId) AND \(deletedVisibility(userId: userId))
        """
    }

    /// Deleted entries carry no StatusDto, note, attachments or reactions; the client renders its own localized placeholder.
    private func deletedMessageDto(_ message: DeletedDirectMessage, on context: ExecutionContext) async throws -> DirectMessageDto {
        let author = try await message.$author.get(on: context.db)
        let recipients = try await DeletedDirectMessageRecipient.query(on: context.db)
            .filter(\.$message.$id == message.requireID())
            .with(\.$user)
            .sort(\.$user.$id)
            .all()

        return DirectMessageDto(id: try String(message.requireID()),
                                conversationId: String(message.$conversation.id),
                                status: nil,
                                recipients: recipients.map { userDto($0.user, on: context) },
                                readAt: nil,
                                deletedAt: message.deletedAt,
                                author: userDto(author, on: context),
                                publishedAt: message.publishedAt,
                                replyToStatusId: message.replyToStatusId.map(String.init))
    }

    /// Saves an outbox event in the message transaction. Network delivery starts only after commit.
    /// Each destination is a personal inbox of an explicit remote recipient; followers are never consulted.
    private func prepareDelivery(status: Status, on context: ExecutionContext) async throws -> ActivityPubStatusJobDataDto? {
        let recipients = try await StatusRecipient.query(on: context.db)
            .filter(\.$status.$id == status.requireID())
            .with(\.$user)
            .all()

        let remoteUsers = recipients.map(\.user).filter { $0.isLocal == false }

        guard remoteUsers.isEmpty == false else {
            return nil
        }

        var inboxes: Set<String> = []

        for user in remoteUsers {
            guard let inbox = user.userInbox, let url = URL(string: inbox), url.host != nil,
                  ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
                throw DirectMessageError.recipientUnavailable
            }

            inboxes.insert(inbox)
        }

        let eventId = context.services.snowflakeService.generate()
        let payload = ActivityPubStatusJobDataDto(statusActivityPubEventId: eventId)
        let event = StatusActivityPubEvent(id: eventId,
                                           statusId: try status.requireID(),
                                           userId: status.$user.id,
                                           type: .create,
                                           eventContext: try payload.encode())
        try await event.create(on: context.db)

        for inbox in inboxes.sorted() {
            let item = StatusActivityPubEventItem(id: context.services.snowflakeService.generate(),
                                                  statusActivityPubEventId: eventId,
                                                  url: inbox)
            try await item.create(on: context.db)
        }

        return payload
    }

    private func ids(_ values: [String]) throws -> [Int64] {
        try values.map { value in

            guard let id = value.toId(), id > 0 else {
                throw DirectMessageError.invalidId
            }

            return id
        }
    }

    /// A write lock serializes inbox updates for a conversation on SQLite and PostgreSQL.
    private func lockConversation(id: Int64, on database: Database) async throws {
        try await DirectConversation.query(on: database)
            .filter(\.$id == id)
            .set(\.$updatedAt, to: Date())
            .update()
    }
}
