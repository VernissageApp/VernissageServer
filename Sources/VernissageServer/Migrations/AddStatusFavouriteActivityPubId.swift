//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent

extension StatusFavourite {
    /// Stores the remote Like identity so a delayed Undo cannot remove a newer favourite.
    struct AddActivityPubId: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(StatusFavourite.schema)
                .field("activityPubId", .string)
                .update()
        }

        func revert(on database: Database) async throws {
            try await database.schema(StatusFavourite.schema)
                .deleteField("activityPubId")
                .update()
        }
    }
}
