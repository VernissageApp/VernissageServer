//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Persistent follow-related ActivityPub delivery created during account migration.
final class MigrationFollowActivityPubEventItem: Model, @unchecked Sendable {
    static let schema = "MigrationFollowActivityPubEventItems"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "migrationFollowActivityPubEventId")
    var migrationFollowActivityPubEvent: MigrationFollowActivityPubEvent

    @Parent(key: "actorUserId")
    var actor: User

    @Field(key: "type")
    var type: MigrationFollowActivityPubEventItemType

    @Field(key: "source")
    var source: String

    @Field(key: "target")
    var target: String

    @Field(key: "inbox")
    var inbox: String

    @Field(key: "activityId")
    var activityId: Int64

    @Field(key: "status")
    var status: MigrationActivityPubEventItemStatus

    @Field(key: "attempts")
    var attempts: Int

    @Timestamp(key: "nextAttemptAt", on: .none)
    var nextAttemptAt: Date?

    @Timestamp(key: "lastAttemptAt", on: .none)
    var lastAttemptAt: Date?

    @Timestamp(key: "processingStartedAt", on: .none)
    var processingStartedAt: Date?

    @Field(key: "processingToken")
    var processingToken: String?

    @Timestamp(key: "endedAt", on: .none)
    var endedAt: Date?

    @Field(key: "httpStatusCode")
    var httpStatusCode: Int?

    @Field(key: "errorMessage")
    var errorMessage: String?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64,
                     migrationFollowActivityPubEventId: Int64,
                     actorUserId: Int64,
                     type: MigrationFollowActivityPubEventItemType,
                     source: String,
                     target: String,
                     inbox: String,
                     activityId: Int64) {
        self.init()

        self.id = id
        self.$migrationFollowActivityPubEvent.id = migrationFollowActivityPubEventId
        self.$actor.id = actorUserId
        self.type = type
        self.source = source
        self.target = target
        self.inbox = inbox
        self.activityId = activityId
        self.status = .waiting
        self.attempts = 0
    }
}

/// Allows `MigrationFollowActivityPubEventItem` to be encoded to and decoded from HTTP messages.
extension MigrationFollowActivityPubEventItem: Content { }
