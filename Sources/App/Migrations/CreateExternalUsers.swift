//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

struct CreateExternalUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database
            .schema(ExternalUser.schema)
            .field(.id, .uint64, .identifier(auto: false))
            .field("type", .string, .required)
            .field("externalId", .string, .required)
            .field("authenticationToken", .string)
            .field("tokenCreatedAt", .datetime)
            .field("userId", .uuid, .references("Users", "id"))
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(ExternalUser.schema).delete()
    }
}
