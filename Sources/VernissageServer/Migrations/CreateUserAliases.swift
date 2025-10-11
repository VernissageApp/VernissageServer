//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension UserAlias {
    struct CreateUserAliases: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(UserAlias.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("alias", .string, .required)
                .field("aliasNormalized", .string, .required)
                .field("activityPubProfile", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserAlias.schema)_aliasIndex")
                    .on(UserAlias.schema)
                    .column("aliasNormalized")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(UserAlias.schema).delete()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserAlias.schema)_userIdIndex")
                    .on(UserAlias.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(UserAlias.schema)_userIdIndex")
                    .on(UserAlias.schema)
                    .run()
            }
        }
    }
}
