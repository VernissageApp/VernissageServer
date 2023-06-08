//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

struct CreateAuthClients: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database
            .schema(AuthClient.schema)
            .field(.id, .uint64, .identifier(auto: false))
            .field("type", .string, .required)
            .field("name", .string, .required)
            .field("uri", .string, .required)
            .field("tenantId", .string)
            .field("clientId", .string, .required)
            .field("clientSecret", .string, .required)
            .field("callbackUrl", .string, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .field("deletedAt", .datetime)
            .unique(on: "uri")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(AuthClient.schema).delete()
    }
}
