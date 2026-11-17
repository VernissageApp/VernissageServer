//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit

extension DirectMessageLikeReceipt {
    struct CreateDirectMessageLikeReceipts: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(DirectMessageLikeReceipt.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusId", .int64, .required, .references(Status.schema, "id", onDelete: .cascade))
                .field("userId", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
                .field("activityPubId", .string, .required)
                .field("isUndone", .bool, .required)
                .field("createdAt", .datetime)
                .unique(on: "statusId", "userId", "activityPubId")
                .create()

            if let sql = database as? SQLDatabase {
                try await sql.create(index: "DirectMessageLikeReceipts_userIdIndex")
                    .on(DirectMessageLikeReceipt.schema)
                    .column("userId")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(DirectMessageLikeReceipt.schema)
                .delete()
        }
    }
}
