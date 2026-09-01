//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Persistent Move delivery created during account migration.
final class MigrationMoveActivityPubEventItem: Model, @unchecked Sendable {
    static let schema = "MigrationMoveActivityPubEventItems"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "eventId")
    var migrationMoveActivityPubEvent: MigrationMoveActivityPubEvent

    @Field(key: "inbox")
    var inbox: String

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

    convenience init(id: Int64, migrationMoveActivityPubEventId: Int64, inbox: String) {
        self.init()

        self.id = id
        self.$migrationMoveActivityPubEvent.id = migrationMoveActivityPubEventId
        self.inbox = inbox
        self.status = .waiting
        self.attempts = 0
    }
}

/// Allows `MigrationMoveActivityPubEventItem` to be encoded to and decoded from HTTP messages.
extension MigrationMoveActivityPubEventItem: Content { }
