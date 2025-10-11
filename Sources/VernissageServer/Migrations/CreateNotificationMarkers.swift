//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension NotificationMarker {
    struct CreateNotificationMarkers: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(NotificationMarker.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("notificationId", .int64, .required, .references(Notification.schema, "id"))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "userId")
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(NotificationMarker.schema)_userIdIndex")
                    .on(NotificationMarker.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(NotificationMarker.schema).delete()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(NotificationMarker.schema)_notificationIdIndex")
                    .on(NotificationMarker.schema)
                    .column("notificationId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(NotificationMarker.schema)_notificationIdIndex")
                    .on(NotificationMarker.schema)
                    .run()
            }
        }
    }
}

