//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

struct CreateAttachments: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database
            .schema(Attachment.schema)
            .field(.id, .int64, .identifier(auto: false))
            .field("fileName", .varchar(100), .required)
            .field("fileSize", .int, .required)
            .field("description", .varchar(500))
            .field("blurhash", .varchar(100))
            .field("originalWidth", .int, .required)
            .field("originalHeight", .int, .required)
            .field("smallWidth", .int, .required)
            .field("smallHeight", .int, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .field("deletedAt", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Attachment.schema).delete()
    }
}
