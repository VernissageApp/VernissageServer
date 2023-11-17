//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Category {
    struct CreateCategories: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Category.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("name", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "name")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Category.schema).delete()
        }
    }
}
