//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Location {
    struct CreateLocations: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Location.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("countryId", .int64, .required, .references(Country.schema, "id"))
                .field("geonameId", .string, .required)
                .field("name", .string, .required)
                .field("namesNormalized", .string, .required)
                .field("longitude", .string, .required)
                .field("latitude", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Location.schema).delete()
        }
    }
    
    struct CreateForeignIndexes: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Location.schema)_countryIdIndex")
                    .on(Location.schema)
                    .column("countryId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(Location.schema)_countryIdIndex")
                    .on(Location.schema)
                    .run()
            }
        }
    }
}
