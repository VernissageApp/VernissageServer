//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension OAuthClientRequest {
    struct CreateOAuthClientRequests: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(OAuthClientRequest.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("authDynamicClientId", .int64, .required, .references(AuthDynamicClient.schema, "id"))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("csrfToken", .varchar(64), .required)
                .field("redirectUri", .varchar(500), .required)
                .field("scope", .varchar(100), .required)
                .field("state", .varchar(100), .required)
                .field("nonce", .varchar(100), .required)
                .field("code", .varchar(32))
                .field("codeGeneratedAt", .datetime)
                .field("authorizedAt", .datetime)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(OAuthClientRequest.schema).delete()
        }
    }
}
