//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Trending status.
final class TrendingStatus: Model, @unchecked Sendable {
    static let schema: String = "TrendingStatuses"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "trendingPeriod")
    var trendingPeriod: TrendingPeriod
    
    @Parent(key: "statusId")
    var status: Status

    @Field(key: "amount")
    var amount: Int
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, trendingPeriod: TrendingPeriod, statusId: Int64, amount: Int) {
        self.init()

        self.id = id
        self.trendingPeriod = trendingPeriod
        self.$status.id = statusId
        self.amount = amount
    }
}

/// Allows `TrendingStatus` to be encoded to and decoded from HTTP messages.
extension TrendingStatus: Content { }
