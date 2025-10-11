//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension SharedBusinessCard {
    struct CreateSharedBusinessCards: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(SharedBusinessCard.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("businessCardId", .int64, .required, .references(BusinessCard.schema, "id"))
                .field("code", .varchar(64), .required)
                .field("title", .varchar(200), .required)
                .field("note", .varchar(500))
                .field("thirdPartyName", .varchar(100), .required)
                .field("thirdPartyEmail", .varchar(500))
                .field("revokedAt", .datetime)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(SharedBusinessCard.schema).delete()
        }
    }
    
    struct CreateForeignIndexes: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(SharedBusinessCard.schema)_businessCardIdIndex")
                    .on(SharedBusinessCard.schema)
                    .column("businessCardId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(SharedBusinessCard.schema)_businessCardIdIndex")
                    .on(SharedBusinessCard.schema)
                    .run()
            }
        }
    }
}
