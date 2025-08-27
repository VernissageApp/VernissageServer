//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension StatusActivityPubEventItem {
    struct CreateStatusActivityPubEventItems: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusActivityPubEventItem.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusActivityPubEventId", .int64, .required, .references(StatusActivityPubEvent.schema, "id"))
                .field("url", .varchar(500), .required)
                .field("isSuccess", .bool)
                .field("errorMessage", .string)
                .field("startAt", .datetime)
                .field("endAt", .datetime)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusActivityPubEventItem.schema)_statusActivityPubEventIdIndex")
                    .on(StatusActivityPubEventItem.schema)
                    .column("statusActivityPubEventId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(StatusActivityPubEventItem.schema).delete()
        }
    }
}
