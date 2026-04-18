//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension SuspendedServer {
    struct CreateSuspendedServers: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(SuspendedServer.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("host", .string, .required)
                .field("hostNormalized", .string, .required)
                .field("numberOfErrors", .int, .required)
                .field("lastErrorDate", .datetime, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "hostNormalized")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema(SuspendedServer.schema).delete()
        }
    }
}
