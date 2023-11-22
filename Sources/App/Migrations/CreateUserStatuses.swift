//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension UserStatus {
    struct CreateUserStatuses: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(UserStatus.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userId", .int64, .required, .references(User.schema, "id"))
                .field("statusId", .int64, .required, .references(Status.schema, "id"))
                .field("createdAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(UserStatus.schema)_userIdIndex")
                    .on(UserStatus.schema)
                    .column("userId")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(UserStatus.schema)_userIdstatusIdIndex")
                    .on(UserStatus.schema)
                    .column("userId")
                    .column("statusId")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(UserStatus.schema).delete()
        }
    }
    
    struct CreateUserStatusTypeColumn: AsyncMigration {
        func prepare(on database: Database) async throws {
            print("PREPAAAERE")
            try await database
                .schema(UserStatus.schema)
                .field("userStatusType", .int, .required, .sql(.default(2)))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(UserStatus.schema)
                .deleteField("userStatusType")
                .update()
        }
    }
}
