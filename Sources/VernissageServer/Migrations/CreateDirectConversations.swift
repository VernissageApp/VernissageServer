//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension DirectConversation {
    struct CreateDirectConversations: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(DirectConversation.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("rootStatusId", .int64, .references(Status.schema, "id", onDelete: .setNull))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(DirectConversation.schema)_rootStatusIdIndex")
                    .on(DirectConversation.schema)
                    .column("rootStatusId")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(DirectConversation.schema).delete()
        }
    }
}
