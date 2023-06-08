//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

struct CreateRoles: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database
            .schema(Role.schema)
            .field(.id, .uint64, .identifier(auto: false))
            .field("code", .string, .required)
            .field("title", .string, .required)
            .field("description", .string)
            .field("hasSuperPrivileges", .bool, .required)
            .field("isDefault", .bool, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .field("deletedAt", .datetime)
            .unique(on: "code")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Role.schema).delete()
    }
}
