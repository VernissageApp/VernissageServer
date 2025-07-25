//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension StatusMention {
    struct CreateStatusMentions: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusMention.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusId", .int64, .required, .references(Status.schema, "id"))
                .field("userName", .string, .required)
                .field("userNameNormalized", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusMention.schema)_userNameIndex")
                    .on(StatusMention.schema)
                    .column("userNameNormalized")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(StatusMention.schema).delete()
        }
    }
    
    struct AddUserUrl: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusMention.schema)
                .field("userUrl", .string)
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(StatusMention.schema)
                .deleteField("userUrl")
                .update()
        }
    }
    
    struct AddStatusIdIndex: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusMention.schema)_statusIdIdIndex")
                    .on(StatusMention.schema)
                    .column("statusId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(StatusMention.schema)_statusIdIdIndex")
                    .on(StatusMention.schema)
                    .run()
            }
        }
    }
}
