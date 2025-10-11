//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Attachment {
    struct CreateAttachments: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Attachment.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("description", .varchar(2000))
                .field("blurhash", .varchar(100))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .field("deletedAt", .datetime)
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("originalFileId", .int64, .required, .references(FileInfo.schema, "id"))
                .field("smallFileId", .int64, .required, .references(FileInfo.schema, "id"))
                .field("locationId", .int64, .references(Location.schema, "id"))
                .field("statusId", .int64, .references(Status.schema, "id"))
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Attachment.schema).delete()
        }
    }
    
    struct AddLicense: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Attachment.schema)
                .field("licenseId", .int64, .references(License.schema, "id"))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Attachment.schema)
                .deleteField("licenseId")
                .update()
        }
    }
    
    struct AddOrginalHdrFileField: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Attachment.schema)
                .field("originalHdrFileId", .int64, .references(FileInfo.schema, "id"))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Attachment.schema)
                .deleteField("originalHdrFileId")
                .update()
        }
    }
    
    struct AddOrderField: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Attachment.schema)
                .field("order", .int, .required, .sql(.default(0)))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Attachment.schema)
                .deleteField("order")
                .update()
        }
    }
    
    struct AddStatusIdIndex: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Attachment.schema)_statusIdIdIndex")
                    .on(Attachment.schema)
                    .column("statusId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(Attachment.schema)_statusIdIdIndex")
                    .on(Attachment.schema)
                    .run()
            }
        }
    }
    
    struct CreateForeignIndices: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Attachment.schema)_userIdIndex")
                    .on(Attachment.schema)
                    .column("userId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(Attachment.schema)_originalFileIdIndex")
                    .on(Attachment.schema)
                    .column("originalFileId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(Attachment.schema)_smallFileIdIndex")
                    .on(Attachment.schema)
                    .column("smallFileId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(Attachment.schema)_locationIdIndex")
                    .on(Attachment.schema)
                    .column("locationId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(Attachment.schema)_licenseIdIndex")
                    .on(Attachment.schema)
                    .column("licenseId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(Attachment.schema)_originalHdrFileIdIndex")
                    .on(Attachment.schema)
                    .column("originalHdrFileId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(Attachment.schema)_userIdIndex")
                    .on(Attachment.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(Attachment.schema)_originalFileIdIndex")
                    .on(Attachment.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(Attachment.schema)_smallFileIdIndex")
                    .on(Attachment.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(Attachment.schema)_locationIdIndex")
                    .on(Attachment.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(Attachment.schema)_licenseIdIndex")
                    .on(Attachment.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(Attachment.schema)_originalHdrFileIdIndex")
                    .on(Attachment.schema)
                    .run()
            }
        }
    }
}
