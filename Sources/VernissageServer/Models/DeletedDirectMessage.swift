//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Content-free record of a removed message. Its id is the original status id, without a status foreign key.
/// Keeps conversation position, authorship and addressing after the status and its content have been deleted.
final class DeletedDirectMessage: Model, @unchecked Sendable {
    static let schema = "DeletedDirectMessages"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "conversationId")
    var conversation: DirectConversation

    @Parent(key: "authorId")
    var author: User

    @Field(key: "activityPubId")
    var activityPubId: String

    @OptionalField(key: "replyToStatusId")
    var replyToStatusId: Int64?

    @OptionalField(key: "replyToActivityPubId")
    var replyToActivityPubId: String?

    @Field(key: "publishedAt")
    var publishedAt: Date

    @Field(key: "deletedAt")
    var deletedAt: Date

    @Children(for: \.$message)
    var recipients: [DeletedDirectMessageRecipient]

    init() { }

    convenience init(status: Status, conversationId: Int64) throws {
        self.init()
        self.id = try status.requireID()
        self.$conversation.id = conversationId
        self.$author.id = status.$user.id
        self.activityPubId = status.activityPubId
        self.replyToStatusId = status.$replyToStatus.id
        self.replyToActivityPubId = status.replyToActivityPubId
        self.publishedAt = status.publishedAt ?? status.createdAt ?? Date()
        self.deletedAt = Date()
    }
}
