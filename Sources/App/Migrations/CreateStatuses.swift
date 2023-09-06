//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Status {
    struct CreateStatuses: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("note", .string, .required)
                .field("visibility", .int, .required)
                .field("sensitive", .bool, .required)
                .field("contentWarning", .varchar(100))
                .field("commentsDisabled", .bool, .required)
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("replyToStatusId", .int64, .references(Status.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Status.schema)_visibilityIndex")
                    .on(Status.schema)
                    .column("userId")
                    .column("visibility")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Status.schema).delete()
        }
    }
    
    struct CreateActivityPubColumns: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .field("isLocal", .bool, .required, .sql(.default(true)))
                .update()
            
            try await database
                .schema(Status.schema)
                .field("activityPubId", .string)
                .update()
            
            try await database
                .schema(Status.schema)
                .field("activityPubUrl", .string)
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(Status.schema)
                .deleteField("isLocal")
                .update()
            
            try await database
                .schema(Status.schema)
                .deleteField("activityPubId")
                .update()
            
            try await database
                .schema(Status.schema)
                .deleteField("activityPubUrl")
                .update()
        }
    }
}
