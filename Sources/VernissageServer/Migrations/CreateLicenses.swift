//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension License {
    struct CreateLicenses: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(License.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("name", .varchar(100), .required)
                .field("code", .varchar(50), .required)
                .field("description", .varchar(1000), .required)
                .field("url", .varchar(500))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(License.schema).delete()
        }
    }
}
