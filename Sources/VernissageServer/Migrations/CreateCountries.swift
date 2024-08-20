//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Country {
    struct CreateCountries: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Country.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("code", .string, .required)
                .field("name", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "code")
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "codeIndex")
                    .on(Country.schema)
                    .column("code")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Country.schema).delete()
        }
    }
}
