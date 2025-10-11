//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension SharedBusinessCardMessage {
    struct CreateSharedBusinessCardMessages: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(SharedBusinessCardMessage.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("sharedBusinessCardId", .int64, .required, .references(SharedBusinessCard.schema, "id"))
                .field("userId", .int64, .references(User.schema, "id"))
                .field("message", .varchar(500), .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(SharedBusinessCardMessage.schema).delete()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(SharedBusinessCardMessage.schema)_sharedBusinessCardIdIndex")
                    .on(SharedBusinessCardMessage.schema)
                    .column("sharedBusinessCardId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(SharedBusinessCardMessage.schema)_userIdIndex")
                    .on(SharedBusinessCardMessage.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(SharedBusinessCardMessage.schema)_sharedBusinessCardIdIndex")
                    .on(SharedBusinessCardMessage.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(SharedBusinessCardMessage.schema)_userIdIndex")
                    .on(SharedBusinessCardMessage.schema)
                    .run()
            }
        }
    }
}
