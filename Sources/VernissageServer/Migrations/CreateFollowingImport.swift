//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension FollowingImport {
    struct CreateFollowingImport: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(FollowingImport.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("status", .int, .required)
                .field("startedAt", .datetime)
                .field("endedAt", .datetime)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "userIdIndex")
                    .on(FollowingImport.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(FollowingImport.schema).delete()
        }
    }
}
