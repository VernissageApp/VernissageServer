//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension ArticleFileInfo {
    struct CreateArticleFileInfos: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(ArticleFileInfo.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("articleId", .int64, .required, .references(Article.schema, "id"))
                .field("fileName", .varchar(100), .required)
                .field("width", .int, .required)
                .field("height", .int, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .field("deletedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(ArticleFileInfo.schema).delete()
        }
    }
}
