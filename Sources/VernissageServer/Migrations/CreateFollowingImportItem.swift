//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension FollowingImportItem {
    struct CreateFollowingImportItem: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(FollowingImportItem.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("followingImportId", .int64, .required, .references(FollowingImport.schema, "id"))
                .field("account", .varchar(500), .required)
                .field("showBoosts", .bool, .required, .sql(.default(false)))
                .field("languages", .varchar(50))
                .field("status", .int, .required)
                .field("errorMessage", .string)
                .field("startedAt", .datetime)
                .field("endedAt", .datetime)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "followingImportIdIndex")
                    .on(FollowingImportItem.schema)
                    .column("followingImportId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(FollowingImportItem.schema).delete()
        }
    }
}
