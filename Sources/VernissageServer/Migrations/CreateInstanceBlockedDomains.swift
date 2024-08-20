//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension InstanceBlockedDomain {
    struct CreateInstanceBlockedDomains: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(InstanceBlockedDomain.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("domain", .string, .required)
                .field("reason", .string)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "domain")
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(InstanceBlockedDomain.schema)_domainIndex")
                    .on(InstanceBlockedDomain.schema)
                    .column("domain")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(InstanceBlockedDomain.schema).delete()
        }
    }
}
