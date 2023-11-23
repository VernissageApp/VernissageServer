//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension TrendingHashtag {
    struct CreateTrendingHashtags: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(TrendingHashtag.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("trendingPeriod", .int, .required)
                .field("hashtag", .string, .required)
                .field("hashtagNormalized", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(TrendingHashtag.schema).delete()
        }
    }
}
