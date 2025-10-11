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
    
    struct CreateForeignIndexes: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(ArticleRead.schema)_userIdIndex")
                    .on(ArticleRead.schema)
                    .column("userId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(ArticleRead.schema)_articleIdIndex")
                    .on(ArticleRead.schema)
                    .column("articleId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(ArticleRead.schema)_userIdIndex")
                    .on(ArticleRead.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(ArticleRead.schema)_articleIdIndex")
                    .on(ArticleRead.schema)
                    .run()
            }
        }
    }
}

