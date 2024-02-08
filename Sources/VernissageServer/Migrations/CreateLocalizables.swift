//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

extension Localizable {
    struct CreateLocalizables: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(Localizable.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("code", .string, .required)
                .field("locale", .string, .required)
                .field("system", .string, .required)
                .field("user", .string)
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
            
            if let sqlDatabase = database as? SQLDatabase {
                try await sqlDatabase
                    .create(index: "\(Localizable.schema)_index")
                    .unique()
                    .on(Localizable.schema)
                    .column("code")
                    .column("locale")
                    .run()
            }
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(UserBlockedDomain.schema).delete()
        }
    }
}
