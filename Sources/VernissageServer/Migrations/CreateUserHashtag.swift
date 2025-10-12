//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension UserHashtag {
    struct CreateUserHashtag: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(UserHashtag.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("hashtag", .string, .required)
                .field("hashtagNormalized", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserHashtag.schema)_hashtagIndex")
                    .on(UserHashtag.schema)
                    .column("hashtagNormalized")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(UserHashtag.schema).delete()
        }
    }
    
    struct CreateForeignIndexes: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserHashtag.schema)_userIdIndex")
                    .on(UserHashtag.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(UserHashtag.schema)_userIdIndex")
                    .on(UserHashtag.schema)
                    .run()
            }
        }
    }
}
