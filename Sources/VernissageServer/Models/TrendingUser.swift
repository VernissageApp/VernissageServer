//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
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
    
    @Field(key: "amount")
    var amount: Int
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, trendingPeriod: TrendingPeriod, userId: Int64, amount: Int) {
        self.init()

        self.id = id
        self.trendingPeriod = trendingPeriod
        self.$user.id = userId
        self.amount = amount
    }
}

/// Allows `TrendingUser` to be encoded to and decoded from HTTP messages.
extension TrendingUser: Content { }
