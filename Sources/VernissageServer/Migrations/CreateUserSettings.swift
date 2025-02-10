//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import SQLiteKit

extension UserSetting {
    struct CreateUserSettings: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(UserSetting.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("key", .string, .required)
                .field("value", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "userId", "key")
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserSetting.schema)_userIdIndex")
                    .on(UserSetting.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(UserSetting.schema).delete()
        }
    }
}
