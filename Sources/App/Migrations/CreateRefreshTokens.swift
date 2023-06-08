//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

struct CreateRefreshTokens: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database
            .schema(RefreshToken.schema)
            .field(.id, .uint64, .identifier(auto: false))
            .field("token", .string, .required)
            .field("expiryDate", .datetime, .required)
            .field("revoked", .bool, .required)
            .field("userId", .uuid, .references("Users", "id"))
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(RefreshToken.schema).delete()
    }
}
