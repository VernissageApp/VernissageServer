//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

struct CreateUserBlockedDomains: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database
            .schema(UserBlockedDomain.schema)
            .field(.id, .uint64, .identifier(auto: false))
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
                .run()
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema(UserBlockedDomain.schema).delete()
    }
}
