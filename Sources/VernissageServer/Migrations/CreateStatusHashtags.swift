//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import SQLiteKit

extension StatusHashtag {
    struct CreateStatusHashtags: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusHashtag.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusId", .int64, .required, .references(Status.schema, "id"))
                .field("hashtag", .string, .required)
                .field("hashtagNormalized", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusHashtag.schema)_hashtagIndex")
                    .on(StatusHashtag.schema)
                    .column("hashtagNormalized")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(StatusHashtag.schema).delete()
        }
    }
    
    struct AddUniqueIndex: AsyncMigration {
        func prepare(on database: Database) async throws {
            // SQLite only supports adding columns in ALTER TABLE statements.
            if let _ = database as? SQLiteDatabase {
                return
            }
            
            try await database
                .schema(StatusHashtag.schema)
                .unique(on: "statusId", "hashtagNormalized")
                .update()
        }
        
        func revert(on database: Database) async throws {
            // SQLite only supports adding columns in ALTER TABLE statements.
            if let _ = database as? SQLiteDatabase {
                return
            }
            
            try await database
                .schema(StatusHashtag.schema)
                .deleteUnique(on: "statusId", "hashtagNormalized")
                .update()
        }
    }
}
