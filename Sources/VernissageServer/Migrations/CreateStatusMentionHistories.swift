//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension StatusMentionHistory {
    struct CreateStatusMentionHistories: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusMentionHistory.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusHistoryId", .int64, .required, .references(StatusHistory.schema, "id"))
                .field("userName", .string, .required)
                .field("userNameNormalized", .string, .required)
                .field("userUrl", .string)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusMentionHistory.schema)_statusHistoryIdIndex")
                    .on(StatusMentionHistory.schema)
                    .column("statusHistoryId")
                    .run()

                try await sqlDatabase
                    .create(index: "\(StatusMentionHistory.schema)_userNameIndex")
                    .on(StatusMentionHistory.schema)
                    .column("userNameNormalized")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(StatusMentionHistory.schema).delete()
        }
    }
}
