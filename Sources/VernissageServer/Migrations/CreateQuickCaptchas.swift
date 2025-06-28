//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension QuickCaptcha {
    struct CreateQuickCaptchas: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(QuickCaptcha.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("key", .varchar(16), .required)
                .field("text", .varchar(12), .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(QuickCaptcha.schema).delete()
        }
    }
    
    struct AddFilterIndexes: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(QuickCaptcha.schema)_createdAtIndex")
                    .on(QuickCaptcha.schema)
                    .column("createdAt")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(QuickCaptcha.schema)_keyIndex")
                    .unique()
                    .on(QuickCaptcha.schema)
                    .column("key")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(QuickCaptcha.schema).delete()
        }
    }
}
