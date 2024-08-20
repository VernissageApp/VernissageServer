//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake
import ActivityPubKit

/// Status bookmark.
final class StatusBookmark: Model, @unchecked Sendable {
    static let schema: String = "StatusBookmarks"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "statusId")
    var status: Status

    @Parent(key: "userId")
    var user: User
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil, statusId: Int64, userId: Int64) {
        self.init()

        self.$status.id = statusId
        self.$user.id = userId
    }
}

/// Allows `StatusBookmark` to be encoded to and decoded from HTTP messages.
extension StatusBookmark: Content { }
