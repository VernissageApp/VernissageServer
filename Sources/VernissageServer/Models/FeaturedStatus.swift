//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Featured status.
final class FeaturedStatus: Model, @unchecked Sendable {
    static let schema: String = "FeaturedStatuses"

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

    init() { }

    convenience init(id: Int64, statusId: Int64, userId: Int64) {
        self.init()

        self.id = id
        self.$status.id = statusId
        self.$user.id = userId
    }
}

/// Allows `FeaturedStatus` to be encoded to and decoded from HTTP messages.
extension FeaturedStatus: Content { }
