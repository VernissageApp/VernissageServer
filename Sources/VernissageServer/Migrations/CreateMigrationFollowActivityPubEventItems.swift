//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension MigrationFollowActivityPubEventItem {
    struct CreateMigrationFollowActivityPubEventItems: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(MigrationFollowActivityPubEventItem.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("migrationFollowActivityPubEventId", .int64, .required,
                       .references(MigrationFollowActivityPubEvent.schema, "id"))
                .field("actorUserId", .int64, .required, .references(User.schema, "id"))
                .field("type", .int, .required)
                .field("source", .varchar(500), .required)
                .field("target", .varchar(500), .required)
                .field("inbox", .varchar(500), .required)
                .field("activityId", .int64, .required)
                .field("status", .int, .required)
                .field("attempts", .int, .required, .sql(.default(0)))
                .field("nextAttemptAt", .datetime)
                .field("lastAttemptAt", .datetime)
                .field("processingStartedAt", .datetime)
                .field("processingToken", .varchar(100))
                .field("endedAt", .datetime)
                .field("httpStatusCode", .int)
                .field("errorMessage", .string)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "migrationFollowActivityPubEventId", "type", "actorUserId")
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "MigrationFollowAPItems_eventIdIndex")
                    .on(MigrationFollowActivityPubEventItem.schema)
                    .column("migrationFollowActivityPubEventId")
                    .run()

                try await sqlDatabase
                    .create(index: "MigrationFollowAPItems_actorUserIdIndex")
                    .on(MigrationFollowActivityPubEventItem.schema)
                    .column("actorUserId")
                    .run()

                try await sqlDatabase
                    .create(index: "MigrationFollowAPItems_statusNextAttemptAtIndex")
                    .on(MigrationFollowActivityPubEventItem.schema)
                    .column("status")
                    .column("nextAttemptAt")
                    .run()

                try await sqlDatabase
                    .create(index: "MigrationFollowAPItems_statusProcessingAtIndex")
                    .on(MigrationFollowActivityPubEventItem.schema)
                    .column("status")
                    .column("processingStartedAt")
                    .run()

                try await sqlDatabase
                    .create(index: "MigrationFollowAPItems_processingTokenIndex")
                    .on(MigrationFollowActivityPubEventItem.schema)
                    .column("processingToken")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(MigrationFollowActivityPubEventItem.schema).delete()
        }
    }

    struct RenameEventIdColumn: AsyncMigration {
        private let oldColumn = "migrationFollowActivityPubEventId"
        private let newColumn = "eventId"

        func prepare(on database: Database) async throws {
            guard let sqlDatabase = database as? SQLDatabase else {
                return
            }

            let query: SQLQueryString = """
                ALTER TABLE \(ident: MigrationFollowActivityPubEventItem.schema)
                RENAME COLUMN \(ident: self.oldColumn) TO \(ident: self.newColumn)
                """
            try await sqlDatabase.raw(query).run()
        }

        func revert(on database: Database) async throws {
            guard let sqlDatabase = database as? SQLDatabase else {
                return
            }

            let query: SQLQueryString = """
                ALTER TABLE \(ident: MigrationFollowActivityPubEventItem.schema)
                RENAME COLUMN \(ident: self.newColumn) TO \(ident: self.oldColumn)
                """
            try await sqlDatabase.raw(query).run()
        }
    }
}
