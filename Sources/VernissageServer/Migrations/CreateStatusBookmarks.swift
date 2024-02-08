//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension StatusBookmark {
    struct CreateStatusBookmarks: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusBookmark.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusId", .int64, .required, .references(Status.schema, "id"))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "statusId", "userId")
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusBookmark.schema)_statusIdIndex")
                    .on(StatusBookmark.schema)
                    .column("statusId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(StatusBookmark.schema)_userIdIndex")
                    .on(StatusBookmark.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(StatusBookmark.schema).delete()
        }
    }
}
