//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension StatusRecipient {
    struct CreateStatusRecipients: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(StatusRecipient.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusId", .int64, .required, .references(Status.schema, "id", onDelete: .cascade))
                .field("userId", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
                .field("recipientType", .int, .required)
                .field("readAt", .datetime)
                .unique(on: "statusId", "userId")
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusRecipient.schema)_userIdReadAtStatusIdIndex")
                    .on(StatusRecipient.schema)
                    .column("userId")
                    .column("readAt")
                    .column("statusId")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(StatusRecipient.schema).delete()
        }
    }
}
