//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import SQLiteKit

extension Status {
    struct CreateStatuses: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("note", .string)
                .field("visibility", .int, .required)
                .field("sensitive", .bool, .required)
                .field("contentWarning", .varchar(100))
                .field("commentsDisabled", .bool, .required)
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("replyToStatusId", .int64, .references(Status.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Status.schema)_visibilityIndex")
                    .on(Status.schema)
                    .column("userId")
                    .column("visibility")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Status.schema).delete()
        }
    }
    
    struct CreateActivityPubColumns: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field("isLocal", .bool, .required, .sql(.default(true)))
                .update()
            
            try await database
                .schema(Status.schema)
                .field("activityPubId", .string, .required)
                .update()
            
            try await database
                .schema(Status.schema)
                .field("activityPubUrl", .string, .required)
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .deleteField("isLocal")
                .update()
            
            try await database
                .schema(Status.schema)
                .deleteField("activityPubId")
                .update()
            
            try await database
                .schema(Status.schema)
                .deleteField("activityPubUrl")
                .update()
        }
    }
    
    struct CreateReblogColumn: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field("reblogId", .int64, .references(Status.schema, "id"))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .deleteField("reblogId")
                .update()
        }
    }
        
    struct CreateCounters: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field("repliesCount", .int, .required, .sql(.default(0)))
                .update()
            
            try await database
                .schema(Status.schema)
                .field("reblogsCount", .int, .required, .sql(.default(0)))
                .update()
            
            try await database
                .schema(Status.schema)
                .field("favouritesCount", .int, .required, .sql(.default(0)))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .deleteField("repliesCount")
                .update()
            
            try await database
                .schema(Status.schema)
                .deleteField("reblogsCount")
                .update()
            
            try await database
                .schema(Status.schema)
                .deleteField("favouritesCount")
                .update()
        }
    }
    
    struct CreateApplicationColumn: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field("application", .varchar(100))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .deleteField("application")
                .update()
        }
    }
    
    struct CreateCategoryColumn: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field("categoryId", .int64, .references(Category.schema, "id"))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .deleteField("categoryId")
                .update()
        }
    }
    
    struct CreateMainReplyToStatusColumn: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field("mainReplyToStatusId", .int64, .references(Status.schema, "id"))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .deleteField("mainReplyToStatusId")
                .update()
        }
    }
    
    struct AddActivityPubIdUniqueIndex: AsyncMigration {
        func prepare(on database: Database) async throws {
            // SQLite only supports adding columns in ALTER TABLE statements.
            if let _ = database as? SQLiteDatabase {
                return
            }
            
            try await database
                .schema(Status.schema)
                .unique(on: "activityPubId")
                .update()
        }
        
        func revert(on database: Database) async throws {
            // SQLite only supports adding columns in ALTER TABLE statements.
            if let _ = database as? SQLiteDatabase {
                return
            }
            
            try await database
                .schema(Status.schema)
                .deleteUnique(on: "activityPubId")
                .update()
        }
    }
    
    struct CreatePublishedAt: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field("publishedAt", .datetime)
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .deleteField("publishedAt")
                .update()
        }
    }
    
    struct CreateUpdatedByUserAt: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field("updatedByUserAt", .datetime)
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .deleteField("updatedByUserAt")
                .update()
        }
    }
}
