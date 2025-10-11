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
    
    struct AddMainArticleFileInfo: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Article.schema)
                .field("mainArticleFileInfoId", .int64, .references(ArticleFileInfo.schema, "id"))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Article.schema)
                .deleteField("mainArticleFileInfoId")
                .update()
        }
    }
    
    struct AddAlternativeAuthor: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Article.schema)
                .field("alternativeAuthor", .varchar(500))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Article.schema)
                .deleteField("alternativeAuthor")
                .update()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Article.schema)_userIdIndex")
                    .on(Article.schema)
                    .column("userId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(Article.schema)_mainArticleFileInfoIdIndex")
                    .on(Article.schema)
                    .column("mainArticleFileInfoId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(Article.schema)_userIdIndex")
                    .on(Article.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(Article.schema)_mainArticleFileInfoIdIndex")
                    .on(Article.schema)
                    .run()
            }
        }
    }
}
