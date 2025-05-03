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
}
