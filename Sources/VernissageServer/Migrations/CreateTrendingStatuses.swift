//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
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
                .field("trendingPeriod", .int, .required)
                .field("statusId", .int64, .required, .references(Status.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "trendingPeriod", "statusId")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(TrendingStatus.schema).delete()
        }
    }
    
    struct AddAmountField: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(TrendingStatus.schema)
                .field("amount", .int, .required, .sql(.default(0)))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(TrendingStatus.schema)
                .deleteField("amount")
                .update()
        }
    }
}
