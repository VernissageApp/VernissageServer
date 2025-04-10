//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension FlexiField {
    struct CreateFlexiFields: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(FlexiField.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("key", .string)
                .field("value", .string)
                .field("isVerified", .bool, .required)
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(FlexiField.schema).delete()
        }
    }
}
