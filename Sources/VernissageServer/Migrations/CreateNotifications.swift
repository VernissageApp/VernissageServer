//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import SQLiteKit

extension Notification {
    struct CreateNotifications: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Notification.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("notificationType", .int, .required)
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("byUserId", .int64, .required, .references(User.schema, "id"))
                .field("statusId", .int64, .references(Status.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Notification.schema)_userIdIndex")
                    .on(Notification.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Notification.schema).delete()
        }
    }
    
    struct AddMainStatus: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Notification.schema)
                .field("mainStatusId", .int64, .references(Status.schema, "id"))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Notification.schema)
                .deleteField("mainStatusId")
                .update()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Notification.schema)_byUserIdIndex")
                    .on(Notification.schema)
                    .column("byUserId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(Notification.schema)_statusIdIndex")
                    .on(Notification.schema)
                    .column("statusId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(Notification.schema)_mainStatusIdIndex")
                    .on(Notification.schema)
                    .column("mainStatusId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(Notification.schema)_byUserIdIndex")
                    .on(Notification.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(Notification.schema)_statusIdIndex")
                    .on(Notification.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(Notification.schema)_mainStatusIdIndex")
                    .on(Notification.schema)
                    .run()
            }
        }
    }
}
