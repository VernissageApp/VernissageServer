//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension UserFollowedHashtag {
    struct CreateUserFollowedHashtag: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(UserFollowedHashtag.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("hashtag", .string, .required)
                .field("hashtagNormalized", .string, .required)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "userId", "hashtagNormalized")
                .create()

            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserFollowedHashtag.schema)_hashtagIndex")
                    .on(UserFollowedHashtag.schema)
                    .column("hashtagNormalized")
                    .run()

                try await sqlDatabase
                    .create(index: "\(UserFollowedHashtag.schema)_userIdIndex")
                    .on(UserFollowedHashtag.schema)
                    .column("userId")
                    .run()
            }
        }

        func revert(on database: Database) async throws {
            try await database.schema(UserFollowedHashtag.schema).delete()
        }
    }
}
