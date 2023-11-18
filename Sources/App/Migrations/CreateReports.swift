//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Report {
    struct CreateReports: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Report.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("reportedUserId", .int64, .required, .references(User.schema, "id"))
                .field("statusId", .int64, .references(Status.schema, "id"))
                .field("comment", .varchar(1000))
                .field("forward", .bool, .required, .sql(.default(false)))
                .field("category", .varchar(100))
                .field("ruleIds", .varchar(100))
                .field("considerationDate", .datetime)
                .field("considerationUserId", .int64, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(Report.schema).delete()
        }
    }
}
