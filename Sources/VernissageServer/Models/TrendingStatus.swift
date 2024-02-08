//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake
import ActivityPubKit

final class TrendingStatus: Model {
    static let schema: String = "TrendingStatuses"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "trendingPeriod")
    var trendingPeriod: TrendingPeriod
    
    @Parent(key: "statusId")
    var status: Status
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil, trendingPeriod: TrendingPeriod, statusId: Int64) {
        self.init()

        self.trendingPeriod = trendingPeriod
        self.$status.id = statusId
    }
}

/// Allows `TrendingStatus` to be encoded to and decoded from HTTP messages.
extension TrendingStatus: Content { }
