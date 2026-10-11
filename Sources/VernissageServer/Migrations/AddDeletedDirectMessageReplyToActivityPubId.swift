//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit

extension DeletedDirectMessage {
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
