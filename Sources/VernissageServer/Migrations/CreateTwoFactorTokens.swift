//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension TwoFactorToken {
    struct CreateTwoFactorTokens: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(TwoFactorToken.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("key", .string, .required)
                .field("backupTokens", .array(of: .string), .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "userId")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(TwoFactorToken.schema).delete()
        }
    }
}
