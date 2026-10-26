//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit

extension DeletedDirectMessage {
    struct CreateDeletedDirectMessages: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(DeletedDirectMessage.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("conversationId", .int64, .required, .references(DirectConversation.schema, "id", onDelete: .cascade))
                .field("authorId", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
                .field("activityPubId", .string, .required)
                .field("replyToStatusId", .int64)
                .field("publishedAt", .datetime, .required)
                .field("deletedAt", .datetime, .required)
                .unique(on: "activityPubId")
                .create()

            if let sql = database as? SQLDatabase {
                try await sql.create(index: "DeletedDirectMessages_conversationIdIdIndex")
                    .on(DeletedDirectMessage.schema)
                    .column("conversationId")
                    .column("id")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(DeletedDirectMessage.schema)
                .delete()
        }
    }

    struct AddReplyToActivityPubId: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(DeletedDirectMessage.schema)
                .field("replyToActivityPubId", .string)
                .update()

            if let sql = database as? SQLDatabase {
                try await sql
                    .create(index: "DeletedDirectMessages_replyToActivityPubIdIndex")
                    .on(DeletedDirectMessage.schema)
                    .column("replyToActivityPubId")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            if let sql = database as? SQLDatabase {
                try await sql
                    .drop(index: "DeletedDirectMessages_replyToActivityPubIdIndex")
                    .run()
            }

            try await database.schema(DeletedDirectMessage.schema)
                .deleteField("replyToActivityPubId")
                .update()
        }
    }
}
