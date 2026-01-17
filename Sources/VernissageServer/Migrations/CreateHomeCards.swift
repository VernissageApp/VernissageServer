//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension HomeCard {
    struct CreateHomeCards: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(HomeCard.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("title", .string, .required)
                .field("body", .string, .required)
                .field("order", .int, .required, .sql(.default(0)))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(HomeCard.schema).delete()
        }
    }
}
