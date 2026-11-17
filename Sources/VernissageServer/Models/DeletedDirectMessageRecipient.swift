//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent

/// Preserves the original explicit audience; conversation membership never grants access to a deleted message.
final class DeletedDirectMessageRecipient: Model, @unchecked Sendable {
    static let schema = "DeletedDirectMessageRecipients"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "messageId")
    var message: DeletedDirectMessage

    @Parent(key: "userId")
    var user: User

    init() { }

    convenience init(id: Int64, messageId: Int64, userId: Int64) {
        self.init()
        self.id = id
        self.$message.id = messageId
        self.$user.id = userId
    }
}
