//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import SQLiteKit

extension StatusHashtagHistory {
    struct CreateStatusHashtagHistories: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusHashtagHistory.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusHistoryId", .int64, .required, .references(StatusHistory.schema, "id"))
                .field("hashtag", .string, .required)
                .field("hashtagNormalized", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "statusHistoryId", "hashtagNormalized")
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusHashtagHistory.schema)_statusHistoryIdIndex")
                    .on(StatusHashtagHistory.schema)
                    .column("statusHistoryId")
                    .run()

                try await sqlDatabase
                    .create(index: "\(StatusHashtagHistory.schema)_hashtagIndex")
                    .on(StatusHashtagHistory.schema)
                    .column("hashtagNormalized")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(StatusHashtagHistory.schema).delete()
        }
    }
}
