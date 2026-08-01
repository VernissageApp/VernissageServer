//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import SQLKit
import Vapor

extension EmailDelivery {
    struct CreateEmailDeliveries: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(EmailDelivery.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("toAddress", .varchar(320), .required)
                .field("toName", .string)
                .field("fromAddress", .varchar(320), .required)
                .field("fromName", .string)
                .field("replyToAddress", .varchar(320))
                .field("replyToName", .string)
                .field("subject", .string, .required)
                .field("body", .string, .required)
                .field("status", .int, .required)
                .field("attempts", .int, .required, .sql(.default(0)))
                .field("nextAttemptAt", .datetime)
                .field("lastAttemptAt", .datetime)
                .field("processingStartedAt", .datetime)
                .field("processingToken", .varchar(100))
                .field("endedAt", .datetime)
                .field("errorMessage", .string)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "EmailDeliveries_statusNextAttemptAtIndex")
                    .on(EmailDelivery.schema)
                    .column("status")
                    .column("nextAttemptAt")
                    .run()

                try await sqlDatabase
                    .create(index: "EmailDeliveries_statusProcessingAtIndex")
                    .on(EmailDelivery.schema)
                    .column("status")
                    .column("processingStartedAt")
                    .run()

                try await sqlDatabase
                    .create(index: "EmailDeliveries_processingTokenIndex")
                    .on(EmailDelivery.schema)
                    .column("processingToken")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(EmailDelivery.schema).delete()
        }
    }
}
