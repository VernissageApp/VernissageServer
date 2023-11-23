//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension TrendingStatus {
    struct CreateTrendingStatuses: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(TrendingStatus.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("trendingStatusPeriod", .int, .required)
                .field("statusId", .int64, .required, .references(Status.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(TrendingStatus.schema).delete()
        }
    }
}
