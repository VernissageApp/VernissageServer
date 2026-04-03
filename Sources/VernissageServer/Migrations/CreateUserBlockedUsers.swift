//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import SQLiteKit

extension UserBlockedUser {
    struct CreateUserBlockedUsers: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(UserBlockedUser.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("blockedUserId", .int64, .required, .references(User.schema, "id"))
                .field("reason", .string)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserBlockedUser.schema)_userIdIndex")
                    .on(UserBlockedUser.schema)
                    .column("userId")
                    .run()
            }
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserBlockedUser.schema)_blockedUserIdIndex")
                    .on(UserBlockedUser.schema)
                    .column("userId")
                    .column("blockedUserId")
                    .unique()
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(UserBlockedUser.schema).delete()
        }
    }
}
