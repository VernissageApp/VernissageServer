//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Invitation {
    struct CreateInvitations: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Invitation.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("code", .string, .required)
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("invitedId", .int64, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Invitation.schema)_codeIndex")
                    .on(Invitation.schema)
                    .column("code")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Invitation.schema).delete()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Invitation.schema)_userIdIndex")
                    .on(Invitation.schema)
                    .column("userId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(Invitation.schema)_invitedIdIndex")
                    .on(Invitation.schema)
                    .column("invitedId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(Invitation.schema)_userIdIndex")
                    .on(Invitation.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(Invitation.schema)_invitedIdIndex")
                    .on(Invitation.schema)
                    .run()
            }
        }
    }
}
