//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension TrendingUser {
    struct CreateTrendingUsers: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(TrendingUser.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("trendingPeriod", .int, .required)
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "trendingPeriod", "userId")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(TrendingUser.schema).delete()
        }
    }
}
