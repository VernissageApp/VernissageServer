//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension ExternalUser {
    struct CreateExternalUsers: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(ExternalUser.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("type", .string, .required)
                .field("externalId", .string, .required)
                .field("authenticationToken", .string)
                .field("tokenCreatedAt", .datetime)
                .field("userId", .int64, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(ExternalUser.schema).delete()
        }
    }
}
