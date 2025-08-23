//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension StatusEmoji {
    struct CreateStatusEmojis: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusEmoji.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusId", .int64, .required, .references(Status.schema, "id"))
                .field("activityPubId", .varchar(500), .required)
                .field("name", .varchar(100), .required)
                .field("mediaType", .varchar(100), .required)
                .field("fileName", .varchar(100), .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(StatusEmoji.schema).delete()
        }
    }
    
    struct AddStatusIdIndex: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusEmoji.schema)_statusIdIdIndex")
                    .on(StatusEmoji.schema)
                    .column("statusId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(StatusEmoji.schema)_statusIdIdIndex")
                    .on(StatusEmoji.schema)
                    .run()
            }
        }
    }
}
