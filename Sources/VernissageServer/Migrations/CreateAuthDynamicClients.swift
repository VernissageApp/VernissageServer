//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension AuthDynamicClient {
    struct CreateAuthDynamicClients: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(AuthDynamicClient.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .references(User.schema, "id"))
                .field("clientSecret", .varchar(32))
                .field("clientSecretExpiresAt", .datetime)
                .field("redirectUris", .string, .required)
                .field("tokenEndpointAuthMethod", .varchar(50))
                .field("grantTypes", .varchar(500), .required)
                .field("responseTypes", .varchar(500), .required)
                .field("clientName", .varchar(200))
                .field("clientUri", .varchar(500))
                .field("logoUri", .varchar(500))
                .field("scope", .varchar(100))
                .field("contacts", .varchar(500))
                .field("tosUri", .varchar(500))
                .field("policyUri", .varchar(500))
                .field("jwksUri", .varchar(500))
                .field("jwks", .string)
                .field("softwareId", .varchar(100))
                .field("softwareVersion", .varchar(100))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(AuthDynamicClient.schema).delete()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(AuthDynamicClient.schema)_userIdIndex")
                    .on(AuthDynamicClient.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(AuthDynamicClient.schema)_userIdIndex")
                    .on(AuthDynamicClient.schema)
                    .run()
            }
        }
    }
}
