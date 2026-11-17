//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// A direct conversation, independent of the lifetime of its first message.
final class DirectConversation: Model, @unchecked Sendable {
    static let schema: String = "DirectConversations"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @OptionalParent(key: "rootStatusId")
    var rootStatus: Status?

    @Children(for: \.$directConversation)
    var statuses: [Status]

    @Children(for: \.$conversation)
    var userConversations: [UserDirectConversation]

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, rootStatusId: Int64? = nil) {
        self.init()
        self.id = id
        self.$rootStatus.id = rootStatusId
    }
}

/// Allows `DirectConversation` to be encoded to and decoded from HTTP messages.
extension DirectConversation: Content { }
