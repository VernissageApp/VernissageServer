//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Article {
    struct CreateArticles: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Article.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("title", .varchar(200))
                .field("body", .string, .required)
                .field("color", .varchar(50))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Article.schema).delete()
        }
    }
}
