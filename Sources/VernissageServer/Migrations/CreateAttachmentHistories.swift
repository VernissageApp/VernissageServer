//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension AttachmentHistory {
    struct CreateAttachmentHistories: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(AttachmentHistory.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("description", .varchar(2000))
                .field("blurhash", .varchar(100))
                .field("order", .int, .required, .sql(.default(0)))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("originalFileId", .int64, .required, .references(FileInfo.schema, "id"))
                .field("smallFileId", .int64, .required, .references(FileInfo.schema, "id"))
                .field("locationId", .int64, .references(Location.schema, "id"))
                .field("licenseId", .int64, .references(License.schema, "id"))
                .field("originalHdrFileId", .int64, .references(FileInfo.schema, "id"))
                .field("statusHistoryId", .int64, .references(StatusHistory.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .field("deletedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(AttachmentHistory.schema)_statusHistoryIdIndex")
                    .on(AttachmentHistory.schema)
                    .column("statusHistoryId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(AttachmentHistory.schema).delete()
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(AttachmentHistory.schema)_userIdIndex")
                    .on(AttachmentHistory.schema)
                    .column("userId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(AttachmentHistory.schema)_originalFileIdIndex")
                    .on(AttachmentHistory.schema)
                    .column("originalFileId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(AttachmentHistory.schema)_smallFileIdIndex")
                    .on(AttachmentHistory.schema)
                    .column("smallFileId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(AttachmentHistory.schema)_locationIdIndex")
                    .on(AttachmentHistory.schema)
                    .column("locationId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(AttachmentHistory.schema)_licenseIdIndex")
                    .on(AttachmentHistory.schema)
                    .column("licenseId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(AttachmentHistory.schema)_originalHdrFileIdIndex")
                    .on(AttachmentHistory.schema)
                    .column("originalHdrFileId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(AttachmentHistory.schema)_userIdIndex")
                    .on(AttachmentHistory.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(AttachmentHistory.schema)_originalFileIdIndex")
                    .on(AttachmentHistory.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(AttachmentHistory.schema)_smallFileIdIndex")
                    .on(AttachmentHistory.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(AttachmentHistory.schema)_locationIdIndex")
                    .on(AttachmentHistory.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(AttachmentHistory.schema)_licenseIdIndex")
                    .on(AttachmentHistory.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(AttachmentHistory.schema)_originalHdrFileIdIndex")
                    .on(AttachmentHistory.schema)
                    .run()
            }
        }
    }
}
