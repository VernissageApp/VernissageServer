//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Exif {
    struct CreateExif: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Exif.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("make", .varchar(50))
                .field("model", .varchar(50))
                .field("lens", .varchar(50))
                .field("createDate", .varchar(50))
                .field("focalLenIn35mmFilm", .varchar(50))
                .field("fNumber", .varchar(50))
                .field("exposureTime", .varchar(50))
                .field("photographicSensitivity", .varchar(50))
                .field("attachmentId", .int64, .required, .references(Attachment.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .field("deletedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Exif.schema).delete()
        }
    }
    
    struct AddFilmColumn: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Exif.schema)
                .field("film", .varchar(50))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Exif.schema)
                .deleteField("film")
                .update()
        }
    }
    
    struct AddGpsCoordinates: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Exif.schema)
                .field("latitude", .varchar(50))
                .update()
            
            try await database
                .schema(Exif.schema)
                .field("longitude", .varchar(50))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Exif.schema)
                .deleteField("latitude")
                .update()
            
            try await database
                .schema(Exif.schema)
                .deleteField("longitude")
                .update()
        }
    }
    
    struct AddSoftware: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Exif.schema)
                .field("software", .varchar(50))
                .update()
            
            try await database
                .schema(Exif.schema)
                .field("chemistry", .varchar(50))
                .update()
            
            try await database
                .schema(Exif.schema)
                .field("scanner", .varchar(50))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Exif.schema)
                .deleteField("software")
                .update()
            
            try await database
                .schema(Exif.schema)
                .deleteField("chemistry")
                .update()
            
            try await database
                .schema(Exif.schema)
                .deleteField("scanner")
                .update()
        }
    }
}
