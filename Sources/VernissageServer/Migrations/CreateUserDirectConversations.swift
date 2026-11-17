//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension UserDirectConversation {
    struct CreateUserDirectConversations: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(UserDirectConversation.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id", onDelete: .cascade))
                .field("conversationId", .int64, .required, .references(DirectConversation.schema, "id", onDelete: .cascade))
                .field("lastStatusId", .int64, .references(Status.schema, "id", onDelete: .setNull))
                .field("summary", .varchar(200))
                .field("lastActivityAt", .datetime, .required)
                .field("lastReadAt", .datetime)
                .field("isMuted", .bool, .required, .sql(.default(false)))
                .unique(on: "userId", "conversationId")
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserDirectConversation.schema)_userIdLastActivityAtIdIndex")
                    .on(UserDirectConversation.schema)
                    .column("userId")
                    .column("lastActivityAt")
                    .column("id")
                    .run()

                try await sqlDatabase
                    .create(index: "\(UserDirectConversation.schema)_conversationIdIndex")
                    .on(UserDirectConversation.schema)
                    .column("conversationId")
                    .run()

                try await sqlDatabase
                    .create(index: "\(UserDirectConversation.schema)_lastStatusIdIndex")
                    .on(UserDirectConversation.schema)
                    .column("lastStatusId")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(UserDirectConversation.schema).delete()
        }
    }
}
