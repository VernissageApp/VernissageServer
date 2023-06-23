//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

struct CreateEvents: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database
            .schema(Event.schema)
            .field(.id, .int64, .identifier(auto: false))
            .field("type", .string, .required)
            .field("method", .string, .required)
            .field("uri", .string, .required)
            .field("wasSuccess", .bool, .required)
            .field("userId", .int64, .references("Users", "id"))
            .field("requestBody", .string)
            .field("responseBody", .string)
            .field("error", .string)
            .field("createdAt", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Event.schema).delete()
    }
}
