//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension ArticleRead {
    struct CreateArticleReads: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(ArticleRead.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("articleId", .int64, .required, .references(Article.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(ArticleRead.schema).delete()
        }
    }
}

