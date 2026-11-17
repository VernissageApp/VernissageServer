//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import FluentSQL

extension PushSubscription {
    /// Adds an independent direct-message push preference, enabled for existing subscriptions.
    struct CreateWebPushDirectMessageEnabledField: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(PushSubscription.schema)
                .field("webPushDirectMessageEnabled", .bool, .required, .sql(.default(true)))
                .update()
        }

        func revert(on database: Database) async throws {
            try await database.schema(PushSubscription.schema)
                .deleteField("webPushDirectMessageEnabled")
                .update()
        }
    }
}
