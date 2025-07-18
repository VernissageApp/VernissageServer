//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit
import SQLiteKit

extension StatusHistory {
    struct CreateStatusHistories: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(StatusHistory.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("note", .string)
                .field("visibility", .int, .required)
                .field("sensitive", .bool, .required)
                .field("contentWarning", .varchar(100))
                .field("commentsDisabled", .bool, .required)
                .field("isLocal", .bool, .required, .sql(.default(true)))
                .field("activityPubId", .string, .required)
                .field("activityPubUrl", .string, .required)
                .field("repliesCount", .int, .required, .sql(.default(0)))
                .field("reblogsCount", .int, .required, .sql(.default(0)))
                .field("favouritesCount", .int, .required, .sql(.default(0)))
                .field("application", .varchar(100))
                .field("orginalStatusId", .int64, .required, .references(Status.schema, "id"))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("replyToStatusId", .int64, .references(Status.schema, "id"))
                .field("reblogId", .int64, .references(Status.schema, "id"))
                .field("categoryId", .int64, .references(Category.schema, "id"))
                .field("mainReplyToStatusId", .int64, .references(Status.schema, "id"))
                .field("publishedAt", .datetime)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusHistory.schema)_orginalStatusIdIndex")
                    .on(StatusHistory.schema)
                    .column("orginalStatusId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(StatusHistory.schema).delete()
        }
    }
}
