//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Setting {
    struct CreateSettings: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Setting.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("key", .string, .required)
                .field("value", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "key")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Setting.schema).delete()
        }
    }
}
