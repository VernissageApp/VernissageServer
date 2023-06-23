//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

struct CreateUserRoles: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(UserRole.schema)
            .field(.id, .int64, .identifier(auto: false))
            .field("userId", .int64, .required, .references("Users", "id"))
            .field("roleId", .int64, .required, .references("Roles", "id"))
            .field("createdAt", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(UserRole.schema).delete()
    }
}
