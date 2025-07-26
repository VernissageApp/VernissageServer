//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import SQLiteKit

extension ExifHistory {
    struct CreateExifHistories: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(ExifHistory.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("make", .varchar(100))
                .field("model", .varchar(100))
                .field("lens", .varchar(100))
                .field("createDate", .varchar(100))
                .field("focalLenIn35mmFilm", .varchar(50))
                .field("fNumber", .varchar(50))
                .field("exposureTime", .varchar(50))
                .field("photographicSensitivity", .varchar(50))
                .field("film", .varchar(100))
                .field("latitude", .varchar(50))
                .field("longitude", .varchar(50))
                .field("software", .varchar(100))
                .field("chemistry", .varchar(100))
                .field("scanner", .varchar(100))
                .field("flash", .varchar(100))
                .field("focalLength", .varchar(50))
                .field("attachmentHistoryId", .int64, .required, .references(AttachmentHistory.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .field("deletedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(ExifHistory.schema)_attachmentHistoryIdIndex")
                    .on(ExifHistory.schema)
                    .column("attachmentHistoryId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(ExifHistory.schema).delete()
        }
    }
}
