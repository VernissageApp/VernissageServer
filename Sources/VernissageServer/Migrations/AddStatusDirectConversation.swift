//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension Status {
    struct AddDirectConversation: AsyncMigration {
        func prepare(on database: Database) async throws {
            // SQLite requires a separate ALTER TABLE statement for each column.
            try await database.schema(Status.schema)
                .field("directConversationId", .int64, .references(DirectConversation.schema, "id", onDelete: .setNull))
                .update()

            try await database.schema(Status.schema)
                .field("replyToActivityPubId", .string)
                .update()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Status.schema)_directConversationIdIdIndex")
                    .on(Status.schema)
                    .column("directConversationId")
                    .column("id")
                    .run()

                try await sqlDatabase
                    .create(index: "\(Status.schema)_replyToActivityPubIdIndex")
                    .on(Status.schema)
                    .column("replyToActivityPubId")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(Status.schema)_directConversationIdIdIndex")
                    .run()

                try await sqlDatabase
                    .drop(index: "\(Status.schema)_replyToActivityPubIdIndex")
                    .run()
            }

            try await database.schema(Status.schema)
                .deleteField("directConversationId")
                .update()

            try await database.schema(Status.schema)
                .deleteField("replyToActivityPubId")
                .update()
        }
    }
}
