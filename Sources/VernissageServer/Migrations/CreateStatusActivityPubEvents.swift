//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension StatusActivityPubEvent {
    struct CreateStatusActivityPubEvents: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusActivityPubEvent.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusId", .int64, .required, .references(Status.schema, "id"))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("type", .int, .required)
                .field("result", .int, .required)
                .field("errorMessage", .string)
                .field("attempts", .int, .required)
                .field("startAt", .datetime)
                .field("endAt", .datetime)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusActivityPubEvent.schema)_statusIdIndex")
                    .on(StatusActivityPubEvent.schema)
                    .column("statusId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(StatusActivityPubEvent.schema)_userIdIndex")
                    .on(StatusActivityPubEvent.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(StatusActivityPubEvent.schema).delete()
        }
    }
}
