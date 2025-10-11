//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension UserMute {
    struct CreateUserMutes: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(UserMute.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("mutedUserId", .int64, .required, .references(User.schema, "id"))
                .field("muteStatuses", .bool, .required, .sql(.default(false)))
                .field("muteReblogs", .bool, .required, .sql(.default(false)))
                .field("muteNotifications", .bool, .required, .sql(.default(false)))
                .field("muteEnd", .datetime)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserMute.schema)_usersIndex")
                    .on(UserMute.schema)
                    .column("userId")
                    .column("mutedUserId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(UserMute.schema).delete()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserMute.schema)_userIdIndex")
                    .on(UserMute.schema)
                    .column("userId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(UserMute.schema)_mutedUserIdIndex")
                    .on(UserMute.schema)
                    .column("mutedUserId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(UserMute.schema)_userIdIndex")
                    .on(UserMute.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(UserMute.schema)_mutedUserIdIndex")
                    .on(UserMute.schema)
                    .run()
            }
        }
    }
}
