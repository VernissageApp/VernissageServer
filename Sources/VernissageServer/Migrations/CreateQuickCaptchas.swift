//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension QuickCaptcha {
    struct CreateQuickCaptchas: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(QuickCaptcha.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("key", .varchar(16), .required)
                .field("text", .varchar(12), .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(QuickCaptcha.schema).delete()
        }
    }
}
