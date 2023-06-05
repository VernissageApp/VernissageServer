//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

struct CreateFollows: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database
            .schema(Follow.schema)
            .id()
            .field("sourceId", .uuid, .required, .references("Users", "id"))
            .field("targetId", .uuid, .required, .references("Users", "id"))
            .field("approved", .bool, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .unique(on: "sourceId", "targetId")
            .create()
        
        if let sqlDatabase = database as? SQLDatabase {
            try await sqlDatabase
                .create(index: "sourceIdIndex")
                .on(Follow.schema)
                .column("sourceId")
                .run()
            
            try await sqlDatabase
                .create(index: "targetIdIndex")
                .on(Follow.schema)
                .column("targetId")
                .run()
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema(Follow.schema).delete()
    }
}
