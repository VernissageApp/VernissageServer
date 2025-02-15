//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Archive {
    struct CreateArchives: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Archive.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("requestDate", .datetime, .required)
                .field("startDate", .datetime)
                .field("endDate", .datetime)
                .field("fileName", .varchar(100))
                .field("status", .int, .required)
                .field("errorMessage", .string)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Archive.schema)_userIdIndex")
                    .on(Archive.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Archive.schema).delete()
        }
    }
}
