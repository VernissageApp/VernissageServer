//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
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
    
    struct CreateNameNormalized: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Category.schema)
                .field("nameNormalized", .string, .required, .sql(.default("")))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Category.schema)
                .deleteField("nameNormalized")
                .update()
        }
    }
    
    struct CreatePriorityColumn: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Category.schema)
                .field("priority", .int, .required, .sql(.default(0)))
                .update()
            
            try await database
                .schema(Category.schema)
                .field("isEnabled", .bool, .required, .sql(.default(true)))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Category.schema)
                .deleteField("priority")
                .update()
            
            try await database
                .schema(Category.schema)
                .deleteField("isEnabled")
                .update()
        }
    }
}
