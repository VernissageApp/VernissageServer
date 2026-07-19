//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import SQLiteKit

extension ArticleMarker {
    struct ActualTableStructure {
        func recreate(on database: Database) async throws {
            try await database.schema(ArticleMarker.schema).delete()

            try await database
                .schema(ArticleMarker.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("articleId", .int64, .required, .references(Article.schema, "id"))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("language", .varchar(50), .required, .sql(.default(ArticleMarker.defaultLanguage.lowercased())))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "userId", "language")
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(ArticleMarker.schema)_userIdIndex")
                    .on(ArticleMarker.schema)
                    .column("userId")
                    .run()

                try await sqlDatabase
                    .create(index: "\(ArticleMarker.schema)_articleIdIndex")
                    .on(ArticleMarker.schema)
                    .column("articleId")
                    .run()
            }
        }
    }

    struct CreateArticleMarkers: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(ArticleMarker.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("articleId", .int64, .required, .references(Article.schema, "id"))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "userId")
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(ArticleMarker.schema)_userIdIndex")
                    .on(ArticleMarker.schema)
                    .column("userId")
                    .run()

                try await sqlDatabase
                    .create(index: "\(ArticleMarker.schema)_articleIdIndex")
                    .on(ArticleMarker.schema)
                    .column("articleId")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(ArticleMarker.schema).delete()
        }
    }

    struct AddLanguageColumn: AsyncMigration {
        func prepare(on database: Database) async throws {
            // SQLite is used only during tests and the table is empty when migrations are executed.
            if database is SQLiteDatabase {
                try await ActualTableStructure().recreate(on: database)
                return
            }

            try await database
                .schema(ArticleMarker.schema)
                .field("language", .varchar(50), .required, .sql(.default(ArticleMarker.defaultLanguage.lowercased())))
                .update()

            try await database
                .schema(ArticleMarker.schema)
                .deleteUnique(on: "userId")
                .update()

            try await database
                .schema(ArticleMarker.schema)
                .unique(on: "userId", "language")
                .update()
        }

        func revert(on database: Database) async throws {
            // SQLite is used only during tests, so the historical structure can be recreated without copying data.
            if database is SQLiteDatabase {
                try await database.schema(ArticleMarker.schema).delete()
                try await CreateArticleMarkers().prepare(on: database)
                return
            }

            try await database
                .schema(ArticleMarker.schema)
                .deleteUnique(on: "userId", "language")
                .update()

            try await database
                .schema(ArticleMarker.schema)
                .unique(on: "userId")
                .update()

            try await database
                .schema(ArticleMarker.schema)
                .deleteField("language")
                .update()
        }
    }
}
