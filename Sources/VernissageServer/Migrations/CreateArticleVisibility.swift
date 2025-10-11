//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension ArticleVisibility {
    struct CreateArticleVisibilities: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(ArticleVisibility.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("articleId", .int64, .required, .references(Article.schema, "id"))
                .field("articleVisibilityType", .int, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(ArticleVisibility.schema).delete()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(ArticleVisibility.schema)_articleIdIndex")
                    .on(ArticleVisibility.schema)
                    .column("articleId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(ArticleVisibility.schema)_articleIdIndex")
                    .on(ArticleVisibility.schema)
                    .run()
            }
        }
    }
}
