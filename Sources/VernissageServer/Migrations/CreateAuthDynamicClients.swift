//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension AuthDynamicClient {
    struct CreateAuthDynamicClients: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(AuthDynamicClient.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("clientSecret", .varchar(50))
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
}
