//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Rule {
    struct CreateRules: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Rule.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("order", .int, .required, .sql(.default(0)))
                .field("text", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Rule.schema).delete()
        }
    }
}
