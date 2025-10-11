//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension CategoryHashtag {
    struct CreateCategoryHashtags: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(CategoryHashtag.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("categoryId", .int64, .required, .references(Category.schema, "id"))
                .field("hashtag", .string, .required)
                .field("hashtagNormalized", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(CategoryHashtag.schema)_hashtagIndex")
                    .on(CategoryHashtag.schema)
                    .column("hashtagNormalized")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(CategoryHashtag.schema).delete()
        }
    }
    
    struct CreateForeignIndexes: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(CategoryHashtag.schema)_categoryIdIndex")
                    .on(CategoryHashtag.schema)
                    .column("categoryId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(CategoryHashtag.schema)_categoryIdIndex")
                    .on(CategoryHashtag.schema)
                    .run()
            }
        }
    }
}
