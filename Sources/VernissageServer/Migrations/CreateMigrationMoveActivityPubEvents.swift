//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension MigrationMoveActivityPubEvent {
    struct CreateMigrationMoveActivityPubEvents: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(MigrationMoveActivityPubEvent.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("sourceUserId", .int64, .required, .references(User.schema, "id"))
                .field("targetUserId", .int64, .required, .references(User.schema, "id"))
                .field("source", .varchar(500), .required)
                .field("target", .varchar(500), .required)
                .field("result", .int, .required)
                .field("errorMessage", .string)
                .field("startedAt", .datetime)
                .field("endedAt", .datetime)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "MigrationMoveAPEvents_sourceUserIdIndex")
                    .on(MigrationMoveActivityPubEvent.schema)
                    .column("sourceUserId")
                    .run()

                try await sqlDatabase
                    .create(index: "MigrationMoveAPEvents_targetUserIdIndex")
                    .on(MigrationMoveActivityPubEvent.schema)
                    .column("targetUserId")
                    .run()

                try await sqlDatabase
                    .create(index: "MigrationMoveAPEvents_resultIndex")
                    .on(MigrationMoveActivityPubEvent.schema)
                    .column("result")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(MigrationMoveActivityPubEvent.schema).delete()
        }
    }
}
