//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension RefreshToken {
    struct CreateRefreshTokens: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(RefreshToken.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("token", .string, .required)
                .field("expiryDate", .datetime, .required)
                .field("revoked", .bool, .required)
                .field("userId", .int64, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(RefreshToken.schema).delete()
        }
    }
}
