//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import SQLKit

struct CreateInvitations: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database
            .schema(Invitation.schema)
            .field(.id, .uint64, .identifier(auto: false))
            .field("code", .string, .required)
            .field("userId", .uint64, .required)
            .field("invitedId", .uint64)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .create()
        
        if let sqlDatabase = database as? SQLDatabase {
            try await sqlDatabase
                .create(index: "\(Invitation.schema)_codeIndex")
                .on(UserBlockedDomain.schema)
                .column("code")
                .run()
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema(Invitation.schema).delete()
    }
}
