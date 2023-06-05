//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

struct CreateBlockedDomains: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database
            .schema(BlockedDomain.schema)
            .id()
            .field("domain", .bool, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .unique(on: "domain")
            .create()
        
        if let sqlDatabase = database as? SQLDatabase {
            try await sqlDatabase
                .create(index: "domainIndex")
                .on(BlockedDomain.schema)
                .column("domain")
                .run()
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema(BlockedDomain.schema).delete()
    }
}
