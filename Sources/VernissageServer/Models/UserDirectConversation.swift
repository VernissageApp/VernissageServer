//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// A direct conversation in a local user's inbox. Membership alone does not grant access to its messages.
final class UserDirectConversation: Model, @unchecked Sendable {
    static let schema: String = "UserDirectConversations"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "userId")
    var user: User

    @Parent(key: "conversationId")
    var conversation: DirectConversation

    @OptionalParent(key: "lastStatusId")
    var lastStatus: Status?

    /// Plain-text preview of the last message available to this user (up to 200 characters).
    @OptionalField(key: "summary")
    var summary: String?

    /// Local time of the latest new message available to this user, used to sort the inbox.
    @Field(key: "lastActivityAt")
    var lastActivityAt: Date

    /// Informational only; individual recipient readAt values determine unread state.
    @Timestamp(key: "lastReadAt", on: .none)
    var lastReadAt: Date?

    @Field(key: "isMuted")
    var isMuted: Bool

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64,
                     userId: Int64,
                     conversationId: Int64,
                     lastActivityAt: Date,
                     lastStatusId: Int64? = nil,
                     summary: String? = nil,
                     lastReadAt: Date? = nil,
                     isMuted: Bool = false) {
        self.init()
        self.id = id
        self.$user.id = userId
        self.$conversation.id = conversationId
        self.$lastStatus.id = lastStatusId
        self.summary = summary
        self.lastActivityAt = lastActivityAt
        self.lastReadAt = lastReadAt
        self.isMuted = isMuted
    }
}

/// Allows `UserDirectConversation` to be encoded to and decoded from HTTP messages.
extension UserDirectConversation: Content { }
