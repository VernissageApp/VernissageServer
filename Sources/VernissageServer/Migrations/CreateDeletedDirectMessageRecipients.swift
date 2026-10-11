//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit

extension DeletedDirectMessageRecipient {
    struct CreateDeletedDirectMessageRecipients: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(DeletedDirectMessageRecipient.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("messageId", .int64, .required, .references(DeletedDirectMessage.schema, "id", onDelete: .cascade))
                .field("userId", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
                .unique(on: "messageId", "userId")
                .create()

            if let sql = database as? SQLDatabase {
                try await sql.create(index: "DeletedDirectMessageRecipients_userIdMessageIdIndex")
                    .on(DeletedDirectMessageRecipient.schema)
                    .column("userId")
                    .column("messageId")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(DeletedDirectMessageRecipient.schema)
                .delete()
        }
    }
}
