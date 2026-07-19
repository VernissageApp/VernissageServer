//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension TimelineMarker {
    struct CreateTimelineMarkers: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(TimelineMarker.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("statusId", .int64, .required, .references(Status.schema, "id"))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("timeline", .int, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "userId", "timeline")
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(TimelineMarker.schema)_statusIdIndex")
                    .on(TimelineMarker.schema)
                    .column("statusId")
                    .run()

                try await sqlDatabase
                    .create(index: "\(TimelineMarker.schema)_userIdIndex")
                    .on(TimelineMarker.schema)
                    .column("userId")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(TimelineMarker.schema).delete()
        }
    }
}
