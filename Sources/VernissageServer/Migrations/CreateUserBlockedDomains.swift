//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension UserBlockedDomain {
    struct CreateUserBlockedDomains: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(UserBlockedDomain.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("domain", .string, .required)
                .field("reason", .string)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "domain")
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserBlockedDomain.schema)_domainIndex")
                    .on(UserBlockedDomain.schema)
                    .column("domain")
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(UserBlockedDomain.schema).delete()
        }
    }
    
    struct CreateForeignIndexes: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserBlockedDomain.schema)_userIdIndex")
                    .on(UserBlockedDomain.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(UserBlockedDomain.schema)_userIdIndex")
                    .on(UserBlockedDomain.schema)
                    .run()
            }
        }
    }
}
