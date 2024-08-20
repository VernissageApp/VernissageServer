//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension DisposableEmail {
    struct CreateDisposableEmails: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(DisposableEmail.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("domain", .string, .required)
                .field("domainNormalized", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "domain")
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "domainNormalizedIndex")
                    .on(DisposableEmail.schema)
                    .column("domainNormalized")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(DisposableEmail.schema).delete()
        }
    }
}
