//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension PushSubscription {
    struct CreatePushSubscriptions: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(PushSubscription.schema)
                .field(.id, .int64, .identifier(auto: false))
                .field("endpoint", .string, .required)
                .field("userAgentPublicKey", .string, .required)
                .field("auth", .string, .required)
                .field("webPushNotificationsEnabled", .bool, .required, .sql(.default(true)))
                .field("webPushMentionEnabled", .bool, .required, .sql(.default(true)))
                .field("webPushStatusEnabled", .bool, .required, .sql(.default(true)))
                .field("webPushReblogEnabled", .bool, .required, .sql(.default(true)))
                .field("webPushFollowEnabled", .bool, .required, .sql(.default(true)))
                .field("webPushFollowRequestEnabled", .bool, .required, .sql(.default(true)))
                .field("webPushFavouriteEnabled", .bool, .required, .sql(.default(true)))
                .field("webPushUpdateEnabled", .bool, .required, .sql(.default(true)))
                .field("webPushAdminSignUpEnabled", .bool, .required, .sql(.default(true)))
                .field("webPushAdminReportEnabled", .bool, .required, .sql(.default(true)))
                .field("webPushNewCommentEnabled", .bool, .required, .sql(.default(true)))
                .field("userId", .int64, .references(User.schema, "id"))
                .field("createdAt", .datetime)
                .field("updatedAt", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(PushSubscription.schema).delete()
        }
    }
    
    struct CreateAmmountOfErrorsField: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database
                .schema(PushSubscription.schema)
                .field("ammountOfErrors", .int, .required, .sql(.default(0)))
                .update()
        }
        
        func revert(on database: Database) async throws {
            try await database
                .schema(PushSubscription.schema)
                .deleteField("ammountOfErrors")
                .update()
        }
    }
}
