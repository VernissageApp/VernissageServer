//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension ErrorItem {
    struct CreateErrorItems: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(ErrorItem.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("source", .int, .required)
                .field("code", .varchar(10), .required)
                .field("message", .string, .required)
                .field("exception", .string)
                .field("userAgent", .string)
                .field("clientVersion", .varchar(50))
                .field("serverVersion", .varchar(50))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(ErrorItem.schema).delete()
        }
    }
}
