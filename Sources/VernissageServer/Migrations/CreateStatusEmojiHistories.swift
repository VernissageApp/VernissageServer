//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension StatusEmojiHistory {
    struct CreateStatusEmojiHistories: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusEmojiHistory.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusHistoryId", .int64, .required, .references(StatusHistory.schema, "id"))
                .field("activityPubId", .varchar(500), .required)
                .field("name", .varchar(100), .required)
                .field("mediaType", .varchar(100), .required)
                .field("fileName", .varchar(100), .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusEmojiHistory.schema)_statusHistoryIdIndex")
                    .on(StatusEmojiHistory.schema)
                    .column("statusHistoryId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(StatusEmojiHistory.schema).delete()
        }
    }
}
