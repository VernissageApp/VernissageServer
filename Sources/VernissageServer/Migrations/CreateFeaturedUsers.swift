//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension FeaturedUser {
    struct CreateFeaturedUsers: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(FeaturedUser.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("featuredUserId", .int64, .required, .references(User.schema, "id"))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .unique(on: "featuredUserId", "userId")
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(FeaturedUser.schema)_featuredUserIdIndex")
                    .on(FeaturedStatus.schema)
                    .column("statusId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(FeaturedUser.schema)_userIdIndex")
                    .on(FeaturedStatus.schema)
                    .column("userId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(FeaturedUser.schema).delete()
        }
    }
}
