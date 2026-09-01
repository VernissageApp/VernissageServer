//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension MigrationMoveActivityPubEventItem {
    struct CreateMigrationMoveActivityPubEventItems: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(MigrationMoveActivityPubEventItem.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("migrationMoveActivityPubEventId", .int64, .required,
                       .references(MigrationMoveActivityPubEvent.schema, "id"))
                .field("inbox", .varchar(500), .required)
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
                .unique(on: "migrationMoveActivityPubEventId", "inbox")
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "MigrationMoveAPItems_eventIdIndex")
                    .on(MigrationMoveActivityPubEventItem.schema)
                    .column("migrationMoveActivityPubEventId")
                    .run()

                try await sqlDatabase
                    .create(index: "MigrationMoveAPItems_statusNextAttemptAtIndex")
                    .on(MigrationMoveActivityPubEventItem.schema)
                    .column("status")
                    .column("nextAttemptAt")
                    .run()

                try await sqlDatabase
                    .create(index: "MigrationMoveAPItems_statusProcessingAtIndex")
                    .on(MigrationMoveActivityPubEventItem.schema)
                    .column("status")
                    .column("processingStartedAt")
                    .run()

                try await sqlDatabase
                    .create(index: "MigrationMoveAPItems_processingTokenIndex")
                    .on(MigrationMoveActivityPubEventItem.schema)
                    .column("processingToken")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(MigrationMoveActivityPubEventItem.schema).delete()
        }
    }

    struct RenameEventIdColumn: AsyncMigration {
        private let oldColumn = "migrationMoveActivityPubEventId"
        private let newColumn = "eventId"

        func prepare(on database: Database) async throws {
            guard let sqlDatabase = database as? SQLDatabase else {
                return
            }

            let query: SQLQueryString = """
                ALTER TABLE \(ident: MigrationMoveActivityPubEventItem.schema)
                RENAME COLUMN \(ident: self.oldColumn) TO \(ident: self.newColumn)
                """
            try await sqlDatabase.raw(query).run()
        }

        func revert(on database: Database) async throws {
            guard let sqlDatabase = database as? SQLDatabase else {
                return
            }

            let query: SQLQueryString = """
                ALTER TABLE \(ident: MigrationMoveActivityPubEventItem.schema)
                RENAME COLUMN \(ident: self.newColumn) TO \(ident: self.oldColumn)
                """
            try await sqlDatabase.raw(query).run()
        }
    }
}
