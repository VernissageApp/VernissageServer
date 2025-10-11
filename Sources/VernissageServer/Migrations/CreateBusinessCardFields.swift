//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension BusinessCardField {
    struct CreateBusinessCardFields: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(BusinessCardField.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("businessCardId", .int64, .required, .references(BusinessCard.schema, "id"))
                .field("key", .varchar(200), .required)
                .field("value", .varchar(500), .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(BusinessCardField.schema).delete()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(BusinessCardField.schema)_businessCardIdIndex")
                    .on(BusinessCardField.schema)
                    .column("businessCardId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(BusinessCardField.schema)_businessCardIdIndex")
                    .on(BusinessCardField.schema)
                    .run()
            }
        }
    }
}
