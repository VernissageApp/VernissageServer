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
            .field(.id, .int64, .identifier(auto: false))
            .field("type", .string, .required)
            .field("name", .varchar(50), .required)
            .field("uri", .varchar(300), .required)
            .field("tenantId", .varchar(200))
            .field("clientId", .varchar(200), .required)
            .field("clientSecret", .varchar(200), .required)
            .field("callbackUrl", .varchar(300), .required)
            .field("svgIcon", .varchar(8000))
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
