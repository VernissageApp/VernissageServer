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
                .field("orginalStatusUpdatedAt", .datetime)
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
    
    struct CreateForeignIndexes: AsyncMigration {
        func prepare(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(StatusHistory.schema)_userIdIndex")
                    .on(StatusHistory.schema)
                    .column("userId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(StatusHistory.schema)_replyToStatusIdIndex")
                    .on(StatusHistory.schema)
                    .column("replyToStatusId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(StatusHistory.schema)_reblogIdIndex")
                    .on(StatusHistory.schema)
                    .column("reblogId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(StatusHistory.schema)_categoryIdIndex")
                    .on(StatusHistory.schema)
                    .column("categoryId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(StatusHistory.schema)_mainReplyToStatusIdIndex")
                    .on(StatusHistory.schema)
                    .column("mainReplyToStatusId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .drop(index: "\(StatusHistory.schema)_userIdIndex")
                    .on(StatusHistory.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(StatusHistory.schema)_replyToStatusIdIndex")
                    .on(StatusHistory.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(StatusHistory.schema)_reblogIdIndex")
                    .on(StatusHistory.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(StatusHistory.schema)_categoryIdIndex")
                    .on(StatusHistory.schema)
                    .run()
                
                try await sqlDatabase
                    .drop(index: "\(StatusHistory.schema)_mainReplyToStatusIdIndex")
                    .on(StatusHistory.schema)
                    .run()
            }
        }
    }
}
