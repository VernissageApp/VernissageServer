//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension FailedLogin {
    struct CreateFailedLogins: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(FailedLogin.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("userName", .varchar(200), .required)
                .field("userNameNormalized", .varchar(200), .required)
                .field("ip", .varchar(200))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(FailedLogin.schema)_createdAtIndex")
                    .on(FailedLogin.schema)
                    .column("createdAt")
                    .run()
                
                try await sqlDatabase
                    .create(index: "\(FailedLogin.schema)_filterIndex")
                    .on(FailedLogin.schema)
                    .column("userNameNormalized")
                    .column("createdAt")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(FailedLogin.schema).delete()
        }
    }
}
