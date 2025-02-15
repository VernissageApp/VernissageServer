//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Featured status.
final class FeaturedUser: Model, @unchecked Sendable {
    static let schema: String = "FeaturedUsers"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "featuredUserId")
    var featuredUser: User

    @Parent(key: "userId")
    var user: User
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, featuredUserId: Int64, userId: Int64) {
        self.init()

        self.id = id
        self.$featuredUser.id = featuredUserId
        self.$user.id = userId
    }
}

/// Allows `FeaturedUser` to be encoded to and decoded from HTTP messages.
extension FeaturedUser: Content { }
