//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import SQLiteKit

extension FeaturedStatus {
    struct CreateFeaturedStatuses: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(FeaturedStatus.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusId", .int64, .required, .references(Status.schema, "id"))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "statusId", "userId")
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(FeaturedStatus.schema)_statusIdIndex")
                    .on(FeaturedStatus.schema)
                    .column("statusId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(FeaturedStatus.schema)_userIdIndex")
                    .on(FeaturedStatus.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(FeaturedStatus.schema).delete()
        }
    }
    
    struct ChangeUniqueIndex: AsyncMigration {
        func prepare(on database: Database) async throws {
            // SQLite only supports adding columns in ALTER TABLE statements.
            if let _ = database as? SQLiteDatabase {
                return
            }
            
            try await database
                .schema(FeaturedStatus.schema)
                .deleteUnique(on: "statusId", "userId")
                .update()
            
            try await database
                .schema(FeaturedStatus.schema)
                .unique(on: "statusId")
                .update()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(FeaturedStatus.schema)_statusIdIndex")
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(FeaturedStatus.schema)_userIdIndex")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            // SQLite only supports adding columns in ALTER TABLE statements.
            if let _ = database as? SQLiteDatabase {
                return
            }
            
            try await database
                .schema(FeaturedStatus.schema)
                .deleteUnique(on: "statusId")
                .update()
            
            try await database
                .schema(FeaturedStatus.schema)
                .unique(on: "statusId", "userId")
                .update()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(FeaturedStatus.schema)_userIdIndex")
                    .on(FeaturedStatus.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(FeaturedStatus.schema)_userIdIndex")
                    .on(FeaturedStatus.schema)
                    .run()
            }
        }
    }
}
