//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension BusinessCard {
    struct CreateBusinessCards: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(BusinessCard.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("title", .varchar(200), .required)
                .field("subtitle", .varchar(500))
                .field("body", .string)
                .field("website", .varchar(500))
                .field("telephone", .varchar(50))
                .field("email", .varchar(500))
                .field("color1", .varchar(50), .required)
                .field("color2", .varchar(50), .required)
                .field("color3", .varchar(50), .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(BusinessCard.schema).delete()
        }
    }
}
