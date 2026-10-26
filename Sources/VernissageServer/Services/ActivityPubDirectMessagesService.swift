//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit
import SwiftSoup
import SQLKit

extension Application.Services {
    struct ActivityPubDirectMessagesServiceKey: StorageKey {
        typealias Value = ActivityPubDirectMessagesServiceType
    }

    var activityPubDirectMessagesService: ActivityPubDirectMessagesServiceType {
        get {
            self.application.storage[ActivityPubDirectMessagesServiceKey.self] ?? ActivityPubDirectMessagesService()
        }
        nonmutating set {
            self.application.storage[ActivityPubDirectMessagesServiceKey.self] = newValue
        }
    }
}

/// Receives authenticated private ActivityPub notes and preserves explicit per-message access.
protocol ActivityPubDirectMessagesServiceType: Sendable {
    /// Consumes a private Create after its inbox job has validated the HTTP signature.
    /// Object addressing takes precedence over envelope addressing; tags never grant access.
    /// Missing parents are retained, and later parent delivery reconciles related conversations.
    func receive(note: NoteDto, activity: ActivityDto, inboxRecipientId: Int64?, on context: ExecutionContext) async throws

    /// Applies a signed remote edit to an existing private message; addressing and thread identity remain unchanged.
    /// Explicit remote edit dates prevent duplicate or older versions from overwriting the current message.
    func update(note: NoteDto, activity: ActivityDto, on context: ExecutionContext) async throws

    /// Atomically stores a prepared, authenticated mentioned status and its normalized explicit audience.
    /// The caller resolves actor ids to users and verifies the activity before calling this method.
    /// Unknown parents are retained in Status.replyToActivityPubId.
    func store(status: Status, recipientIds: [Int64], conversationId: Int64?, on context: ExecutionContext) async throws -> Status
}

final class ActivityPubDirectMessagesService: ActivityPubDirectMessagesServiceType {
    public func store(status: Status, recipientIds: [Int64], conversationId: Int64?, on context: ExecutionContext) async throws -> Status {
        let result = try await context.db.transaction { database in

            try await context.services.directMessagesService.store(status: status, recipientIds: recipientIds,
                conversationId: conversationId, on: context.with(transaction: database))
        }

        await context.services.directMessagesService.dispatchNotifications(result.notifications, on: context)

        return result.status
    }

    /// Stores one authenticated private note, including text-only messages, without public timeline side effects.
    /// Duplicate or previously deleted objects are consumed without resetting read state or notifying again.
    public func receive(note: NoteDto, activity: ActivityDto, inboxRecipientId: Int64?, on context: ExecutionContext) async throws {
        let actors = activity.actor.actorIds()

        guard actors.count == 1, let actorId = actors.first, note.attributedTo == actorId,
              sameOrigin(note.id, actorId) else {
            context.logger.warning("[DirectMessages] Create actor does not match note ownership.")

            return
        }

        let addresses = addressedActors(note: note, activity: activity)
        let knownLocalRecipients = try await User.query(on: context.db)
            .filter(\.$activityPubProfile ~~ addresses)
            .filter(\.$isLocal == true)
            .all()

        guard knownLocalRecipients.isEmpty == false,
              inboxRecipientId == nil || knownLocalRecipients.contains(where: { $0.id == inboxRecipientId }) else {
            return
        }

        guard let author = try await context.services.activityPubDownloadUserService.downloadIfNeeded(activityPubProfile: actorId, on: context),
              author.isLocal == false, author.isBlocked == false, author.isSuppressed == false else {
            return
        }

        guard try await eligibleLocalRecipients(knownLocalRecipients, author: author, on: context).isEmpty == false,
              try await alreadyConsumed(note.id, on: context.db) == false else {
            return
        }

        let text = try SwiftSoup.parse(note.content ?? "").text().trimmingCharacters(in: .whitespacesAndNewlines)

        guard text.isEmpty == false || note.attachment?.hasSupportedImages() == true else {
            return
        }

        // Resolve concrete remote actors for the participant list and future delivery; collections and mentions are not audiences.
        var recipients = knownLocalRecipients

        for address in addresses where address != actorId && knownLocalRecipients.contains(where: { $0.activityPubProfile == address }) == false {
            if let user = try await context.services.activityPubDownloadUserService.downloadIfNeeded(activityPubProfile: address, on: context) {
                recipients.append(user)
            }
        }

        // Network and file operations happen before taking conversation/database locks.
        let attachments = try await context.services.statusesService.downloadDirectMessageAttachments(note: note,
            userId: author.requireID(), on: context)
        let status = Status(id: context.services.snowflakeService.generate(), isLocal: false, userId: try author.requireID(),
            note: note.content ?? "", activityPubId: note.id, activityPubUrl: note.url.isEmpty ? note.id : note.url,
            application: nil, categoryId: nil, visibility: .mentioned, sensitive: note.sensitive ?? false,
            contentWarning: note.summary, publishedAt: note.published?.fromISO8601String(), replyToActivityPubId: note.inReplyTo)

        let resolvedRecipients = recipients
        let toActors = Set(note.to != nil || note.cc != nil ? (note.to?.actorIds() ?? []) : (activity.to?.actorIds() ?? []))
        let ccRecipientIds = try resolvedRecipients.filter { toActors.contains($0.activityPubProfile) == false }
            .map { try $0.requireID() }
        let notifications = try await context.db.transaction { database in
            let transaction = context.with(transaction: database)

            // Lock addressed users in a stable order before any transactional reads. Overlapping deliveries serialize,
            // including duplicates to shared/personal inboxes, and SQLite acquires its write lock before reading.
            let lockIds = Set(try resolvedRecipients.map { try $0.requireID() }).union([try author.requireID()])

            guard let sql = database as? SQLDatabase else {
                throw Abort(.internalServerError, reason: "Direct-message persistence requires SQL.")
            }

            for id in lockIds.sorted() {
                try await sql.raw("""
                    UPDATE \(ident: User.schema) SET \(ident: "updatedAt") = \(ident: "updatedAt")
                    WHERE \(ident: "id") = \(bind: id)
                    """).run()
            }

            guard try await self.alreadyConsumed(note.id, on: database) == false else {
                return [Notification]()
            }

            // Recheck account flags after media download, under the user locks, so concurrent blocking is respected.
            guard let currentAuthor = try await User.find(author.requireID(), on: database),
                  currentAuthor.isLocal == false, currentAuthor.isBlocked == false, currentAuthor.isSuppressed == false else {
                return [Notification]()
            }

            let localIds = try knownLocalRecipients.map { try $0.requireID() }
            let currentLocalRecipients = try await User.query(on: database)
                .filter(\.$id ~~ localIds)
                .filter(\.$isLocal == true)
                .all()

            // Check the complete original audience, including remote co-recipients. Filtering it first could
            // hide a blocked participant and incorrectly admit another local recipient.
            let eligibleIds = try await transaction.services.directMessagesService.eligibleRecipientIds(
                authorId: currentAuthor.requireID(), recipientIds: resolvedRecipients.map { try $0.requireID() }, on: transaction)
            let local = currentLocalRecipients.filter { eligibleIds.contains($0.id ?? 0) }

            guard local.isEmpty == false else {
                return [Notification]()
            }

            let audience = Set(try resolvedRecipients.filter { $0.isLocal == false }.map { try $0.requireID() })
                .union(try local.map { try $0.requireID() }).subtracting([try author.requireID()])
            let conversationId = try await self.resolveConversation(status: status, recipientIds: audience, on: transaction)

            // Insert and connect media first, within this transaction, so the common store sees image-only content.
            try await status.create(on: database)

            for attachment in attachments {
                attachment.$status.id = status.id
                try await attachment.save(on: database)
            }

            let result = try await transaction.services.directMessagesService.store(status: status,
                recipientIds: Array(audience), conversationId: conversationId, on: transaction)

            // Preserve to/cc classification for future outgoing activities; both grant the same explicit access.
            if ccRecipientIds.isEmpty == false {
                try await StatusRecipient.query(on: database)
                    .filter(\.$status.$id == status.requireID())
                    .filter(\.$user.$id ~~ ccRecipientIds)
                    .set(\.$recipientType, to: .cc)
                    .update()
            }

            try await self.attachPendingReplies(to: status, recipientIds: audience, on: transaction)

            if note.inReplyTo == nil {
                try await DirectConversation.query(on: database)
                    .filter(\.$id == conversationId)
                    .set(\.$rootStatus.$id, to: status.id)
                    .update()
            }

            return result.notifications
        }

        await context.services.directMessagesService.dispatchNotifications(notifications, on: context)
    }

    /// Receives remote content edits without creating inbox entries, notifications or outgoing activities.
    /// Media downloads happen before locking; persistence and preview changes commit together.
    public func update(note: NoteDto, activity: ActivityDto, on context: ExecutionContext) async throws {
        guard let original = try await context.services.statusesService.get(activityPubId: note.id, on: context.db),
              let conversationId = original.$directConversation.id,
              canUpdate(status: original, note: note, activity: activity) else {
            return
        }

        // Avoid network work for known stale edits; the same check runs again under the conversation lock.
        let attachments = try await context.services.statusesService.downloadDirectMessageAttachments(
            note: note, userId: original.$user.id, on: context)
        let statusId = try original.requireID()

        try await context.db.transaction { database in
            let transaction = context.with(transaction: database)

            // Serialize with creation and deletion, and re-read after locking to avoid resurrecting a deleted message.
            try await DirectConversation.query(on: database)
                .filter(\.$id == conversationId)
                .set(\.$updatedAt, to: Date())
                .update()

            guard let status = try await transaction.services.statusesService.get(id: statusId, on: database),
                  status.$directConversation.id == conversationId,
                  self.canUpdate(status: status, note: note, activity: activity) else {
                return
            }

            try await self.preserveHistory(status: status, on: transaction)

            // Ignore to/cc, mentions, visibility and inReplyTo in Update: they cannot grant or remove access.
            status.note = note.content ?? ""
            status.sensitive = note.sensitive ?? false
            status.contentWarning = note.summary
            status.updatedByUserAt = self.remoteEditDate(note.updated) ?? Date()
            try await status.save(on: database)

            // History retains the old files; unattached originals follow the existing attachment cleanup process.
            for attachment in status.attachments {
                attachment.$status.id = nil
                try await attachment.save(on: database)
            }

            for attachment in attachments {
                attachment.$status.id = statusId
                try await attachment.save(on: database)
            }

            try await transaction.services.directMessagesService.refreshPreview(status: status, on: transaction)
        }
    }

    private func canUpdate(status: Status, note: NoteDto, activity: ActivityDto) -> Bool {
        let actors = activity.actor.actorIds()

        guard status.isLocal == false, status.visibility == .mentioned,
              status.user.isLocal == false, status.user.isBlocked == false, status.user.isSuppressed == false,
              actors.count == 1, actors.first == status.user.activityPubProfile,
              note.attributedTo == status.user.activityPubProfile, sameOrigin(note.id, status.user.activityPubProfile) else {
            return false
        }

        // Compare explicit edit versions without changing the local arrival time used for inbox ordering.
        if let updated = remoteEditDate(note.updated), let previous = status.updatedByUserAt {
            return updated > previous
        }

        return true
    }

    private func remoteEditDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        // Federated servers send ISO 8601 dates both with and without fractional seconds.
        return value.fromISO8601String() ?? ISO8601DateFormatter().date(from: value)
    }

    /// Archives the previous content and media using the same history models as ordinary status edits.
    private func preserveHistory(status: Status, on context: ExecutionContext) async throws {
        let generate = context.services.snowflakeService
        let history = try StatusHistory(id: generate.generate(), from: status)
        let historyId = try history.requireID()

        try await history.create(on: context.db)

        for attachment in status.attachments {
            let attachmentHistory = AttachmentHistory(id: generate.generate(), statusHistoryId: historyId, from: attachment)
            try await attachmentHistory.create(on: context.db)

            if let exif = attachment.exif {
                let exifHistory = ExifHistory(id: generate.generate(), attachmentHistoryId: try attachmentHistory.requireID(), from: exif)
                try await exifHistory.create(on: context.db)
            }
        }

        for hashtag in status.hashtags {
            let item = StatusHashtagHistory(id: generate.generate(), statusHistoryId: historyId, from: hashtag)
            try await item.create(on: context.db)
        }

        for mention in status.mentions {
            let item = StatusMentionHistory(id: generate.generate(), statusHistoryId: historyId, from: mention)
            try await item.create(on: context.db)
        }

        for emoji in status.emojis {
            let item = StatusEmojiHistory(id: generate.generate(), statusHistoryId: historyId, from: emoji)
            try await item.create(on: context.db)
        }
    }

    /// Without forwarding/ownership proofs, a signed sender cannot claim a note id hosted by another origin.
    private func sameOrigin(_ objectId: String, _ actorId: String) -> Bool {
        guard let object = URL(string: objectId), let actor = URL(string: actorId),
              let scheme = object.scheme?.lowercased(), ["http", "https"].contains(scheme),
              scheme == actor.scheme?.lowercased(), let host = object.host?.lowercased(),
              host == actor.host?.lowercased() else {
            return false
        }

        let defaultPort = scheme == "https" ? 443 : 80

        return (object.port ?? defaultPort) == (actor.port ?? defaultPort)
    }

    private func addressedActors(note: NoteDto, activity: ActivityDto) -> [String] {
        let addresses = note.to != nil || note.cc != nil
            ? (note.to?.actorIds() ?? []) + (note.cc?.actorIds() ?? [])
            : (activity.to?.actorIds() ?? []) + (activity.cc?.actorIds() ?? [])

        return Array(Set(addresses.filter {
            $0 != "https://www.w3.org/ns/activitystreams#Public" && $0.hasSuffix("/followers") == false
        })).sorted()
    }

    private func alreadyConsumed(_ activityPubId: String, on database: Database) async throws -> Bool {
        if try await Status.query(on: database)
            .filter(\.$activityPubId == activityPubId)
            .first() != nil {
            return true
        }

        return try await DeletedDirectMessage.query(on: database)
            .filter(\.$activityPubId == activityPubId)
            .first() != nil
    }

    private func eligibleLocalRecipients(_ users: [User], author: User, on context: ExecutionContext) async throws -> [User] {
        let eligibleIds = try await context.services.directMessagesService.eligibleRecipientIds(
            authorId: author.requireID(), recipientIds: users.map { try $0.requireID() }, on: context)

        return users.filter { eligibleIds.contains($0.id ?? 0) }
    }

    /// Joins only a private parent visible to this sender. Public or guessed inaccessible parents stay remote references.
    /// A late parent may connect several provisional conversations, without expanding any message's audience.
    private func resolveConversation(status: Status, recipientIds: Set<Int64>, on context: ExecutionContext) async throws -> Int64 {
        let authorId = status.$user.id
        var parentConversationId: Int64?

        // Keep malformed messages, but discard parent references that would close a cycle, including unresolved links.
        if let parentId = status.replyToActivityPubId,
           try await createsReplyCycle(childId: status.activityPubId, parentId: parentId, on: context) {
            status.replyToActivityPubId = nil
        }

        if let parentId = status.replyToActivityPubId {
            if let parent = try await Status.query(on: context.db)
                .filter(\.$activityPubId == parentId)
                .first(),
               let conversationId = parent.$directConversation.id {
                let addressed = try await StatusRecipient.query(on: context.db)
                    .filter(\.$status.$id == parent.requireID())
                    .filter(\.$user.$id == authorId)
                    .count() > 0

                if parent.$user.id == authorId || addressed {
                    parentConversationId = conversationId
                    status.$replyToStatus.id = parent.id
                }
            } else if let parent = try await DeletedDirectMessage.query(on: context.db)
                .filter(\.$activityPubId == parentId)
                .first() {
                let addressed = try await DeletedDirectMessageRecipient.query(on: context.db)
                    .filter(\.$message.$id == parent.requireID())
                    .filter(\.$user.$id == authorId)
                    .count() > 0

                if parent.$author.id == authorId || addressed {
                    parentConversationId = parent.$conversation.id
                }
            }
        }

        // Replies may arrive before their parent. Only replies from this message's audience may join it.
        let allowedAuthors = Array(recipientIds.union([authorId]))
        let children = try await Status.query(on: context.db)
            .filter(\.$replyToActivityPubId == status.activityPubId)
            .filter(\.$directConversation.$id != nil)
            .filter(\.$user.$id ~~ allowedAuthors)
            .all()

        let deletedChildren = try await DeletedDirectMessage.query(on: context.db)
            .filter(\.$replyToActivityPubId == status.activityPubId)
            .filter(\.$author.$id ~~ allowedAuthors)
            .all()

        var conversationIds = Set(children.compactMap { $0.$directConversation.id })
            .union(deletedChildren.map { $0.$conversation.id })

        if let parentConversationId {
            conversationIds.insert(parentConversationId)
        }

        let targetId: Int64

        // Prefer the known parent thread, otherwise choose a stable target for provisional conversations.
        if let existingId = parentConversationId ?? conversationIds.min() {
            targetId = existingId
        } else {
            let conversation = DirectConversation(id: context.services.snowflakeService.generate())

            try await conversation.create(on: context.db)
            targetId = try conversation.requireID()
        }

        // Lock provisional conversations in the same order to avoid deadlocks during concurrent merges.
        for id in conversationIds.sorted() {
            try await DirectConversation.query(on: context.db)
                .filter(\.$id == id)
                .set(\.$updatedAt, to: Date())
                .update()
        }

        for sourceId in conversationIds.sorted() where sourceId != targetId {
            try await mergeConversation(sourceId: sourceId, targetId: targetId, on: context)
        }

        return targetId
    }

    /// Moves inbox entries and messages together; explicit recipients and readAt values are preserved.
    /// For a user with both inbox entries, the newest preview wins and either mute preference remains effective.
    private func mergeConversation(sourceId: Int64, targetId: Int64, on context: ExecutionContext) async throws {
        let inboxes = try await UserDirectConversation.query(on: context.db)
            .filter(\.$conversation.$id == sourceId)
            .all()

        for source in inboxes {
            if let target = try await UserDirectConversation.query(on: context.db)
                .filter(\.$conversation.$id == targetId)
                .filter(\.$user.$id == source.$user.id)
                .first() {
                if source.lastActivityAt > target.lastActivityAt {
                    target.$lastStatus.id = source.$lastStatus.id
                    target.summary = source.summary
                    target.lastActivityAt = source.lastActivityAt
                }

                // Keep either mute preference. Per-message readAt values still determine unread state.
                target.lastReadAt = [target.lastReadAt, source.lastReadAt].compactMap { $0 }.max()
                target.isMuted = target.isMuted || source.isMuted
                try await target.save(on: context.db)
                try await source.delete(on: context.db)
            } else {
                source.$conversation.id = targetId
                try await source.save(on: context.db)
            }
        }

        try await Status.query(on: context.db)
            .filter(\.$directConversation.$id == sourceId)
            .set(\.$directConversation.$id, to: targetId)
            .update()
        try await DeletedDirectMessage.query(on: context.db)
            .filter(\.$conversation.$id == sourceId)
            .set(\.$conversation.$id, to: targetId)
            .update()
        try await DirectConversation.query(on: context.db)
            .filter(\.$id == sourceId)
            .delete()
    }

    private func attachPendingReplies(to status: Status, recipientIds: Set<Int64>, on context: ExecutionContext) async throws {
        guard let conversationId = status.$directConversation.id else {
            throw DirectMessageError.conversationNotFound
        }

        // Resolve pending parent links without changing the explicit audience of any reply.
        let allowedAuthors = Array(recipientIds.union([status.$user.id]))

        let replies = try await Status.query(on: context.db)
            .filter(\.$directConversation.$id == conversationId)
            .filter(\.$replyToActivityPubId == status.activityPubId)
            .filter(\.$user.$id ~~ allowedAuthors)
            .all()

        // Check each pending edge before assigning it: late parents can otherwise complete multi-message cycles.
        for reply in replies {
            if try await createsReplyCycle(childId: reply.activityPubId, parentId: status.activityPubId, on: context) {
                reply.$replyToStatus.id = nil
                reply.replyToActivityPubId = nil
            } else {
                reply.$replyToStatus.id = status.id
            }

            try await reply.save(on: context.db)
        }

        let deletedReplies = try await DeletedDirectMessage.query(on: context.db)
            .filter(\.$conversation.$id == conversationId)
            .filter(\.$replyToActivityPubId == status.activityPubId)
            .filter(\.$author.$id ~~ allowedAuthors)
            .all()

        for reply in deletedReplies {
            if try await createsReplyCycle(childId: reply.activityPubId, parentId: status.activityPubId, on: context) {
                reply.replyToStatusId = nil
                reply.replyToActivityPubId = nil
            } else {
                reply.replyToStatusId = status.id
            }

            try await reply.save(on: context.db)
        }
    }

    /// Follows both resolved parents and remote references, including content-free deletion markers.
    /// Reaching the child or any existing cycle makes the proposed edge unsafe; unknown parents end the check.
    private func createsReplyCycle(childId: String, parentId: String, on context: ExecutionContext) async throws -> Bool {
        var visitedIds: Set<String> = [childId]
        var currentId: String? = parentId

        while let activityPubId = currentId {
            guard visitedIds.insert(activityPubId).inserted else {
                return true
            }

            if let status = try await Status.query(on: context.db)
                .filter(\.$activityPubId == activityPubId).first() {
                if let parentId = status.$replyToStatus.id,
                   let parent = try await Status.find(parentId, on: context.db) {
                    currentId = parent.activityPubId
                } else {
                    currentId = status.replyToActivityPubId
                }
            } else if let deleted = try await DeletedDirectMessage.query(on: context.db)
                .filter(\.$activityPubId == activityPubId).first() {
                if let parentId = deleted.replyToStatusId {
                    let parent = try await Status.find(parentId, on: context.db)
                    let deletedParent = try await DeletedDirectMessage.find(parentId, on: context.db)
                    currentId = parent?.activityPubId ?? deletedParent?.activityPubId ?? deleted.replyToActivityPubId
                } else {
                    currentId = deleted.replyToActivityPubId
                }
            } else {
                return false
            }
        }

        return false
    }
}
