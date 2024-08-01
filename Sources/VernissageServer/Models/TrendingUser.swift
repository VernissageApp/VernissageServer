//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake
import ActivityPubKit

/// Trending user.
final class TrendingUser: Model, @unchecked Sendable {
    static let schema: String = "TrendingUsers"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "trendingPeriod")
    var trendingPeriod: TrendingPeriod
    
    @Parent(key: "userId")
    var user: User
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil, trendingPeriod: TrendingPeriod, userId: Int64) {
        self.init()

        self.trendingPeriod = trendingPeriod
        self.$user.id = userId
    }
}

/// Allows `TrendingUser` to be encoded to and decoded from HTTP messages.
extension TrendingUser: Content { }
