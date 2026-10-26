//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// An explicitly addressed local or remote recipient of a status.
final class StatusRecipient: Model, @unchecked Sendable {
    static let schema: String = "StatusRecipients"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "statusId")
    var status: Status

    @Parent(key: "userId")
    var user: User

    @Field(key: "recipientType")
    var recipientType: StatusRecipientType

    /// Local read state. A remote recipient's read state is unknown, not a federated read receipt.
    @Timestamp(key: "readAt", on: .none)
    var readAt: Date?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64,
                     statusId: Int64,
                     userId: Int64,
                     recipientType: StatusRecipientType = .to,
                     readAt: Date? = nil) {
        self.init()
        self.id = id
        self.$status.id = statusId
        self.$user.id = userId
        self.recipientType = recipientType
        self.readAt = readAt
    }
}

/// Allows `StatusRecipient` to be encoded to and decoded from HTTP messages.
extension StatusRecipient: Content { }
