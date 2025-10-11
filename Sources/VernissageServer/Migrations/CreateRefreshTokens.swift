//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension RefreshToken {
    struct CreateRefreshTokens: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(RefreshToken.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("token", .string, .required)
                .field("expiryDate", .datetime, .required)
                .field("revoked", .bool, .required)
                .field("userId", .int64, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(RefreshToken.schema).delete()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(RefreshToken.schema)_userIdIndex")
                    .on(RefreshToken.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(RefreshToken.schema)_userIdIndex")
                    .on(RefreshToken.schema)
                    .run()
            }
        }
    }
}
