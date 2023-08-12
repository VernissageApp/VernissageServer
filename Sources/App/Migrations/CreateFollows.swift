//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Follow {
    struct CreateFollows: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Follow.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("sourceId", .int64, .required, .references(User.schema, "id"))
                .field("targetId", .int64, .required, .references(User.schema, "id"))
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
    
    struct AddActivityIdToFollows: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Follow.schema)
                .field("activityId", .string)
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Follow.schema)
                .deleteField("activityId")
                .update()
        }
    }
}
