//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Persistent event containing follow-related deliveries created during account migration.
final class MigrationFollowActivityPubEvent: Model, @unchecked Sendable {
    static let schema = "MigrationFollowActivityPubEvents"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "sourceUserId")
    var sourceUser: User

    @Parent(key: "targetUserId")
    var targetUser: User

    @Field(key: "source")
    var source: String

    @Field(key: "target")
    var target: String

    @Field(key: "result")
    var result: MigrationActivityPubEventResult

    @Field(key: "errorMessage")
    var errorMessage: String?

    @Timestamp(key: "startedAt", on: .none)
    var startedAt: Date?

    @Timestamp(key: "endedAt", on: .none)
    var endedAt: Date?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    @Children(for: \.$migrationFollowActivityPubEvent)
    var items: [MigrationFollowActivityPubEventItem]

    init() { }

    convenience init(id: Int64, sourceUserId: Int64, targetUserId: Int64, source: String, target: String) {
        self.init()

        self.id = id
        self.$sourceUser.id = sourceUserId
        self.$targetUser.id = targetUserId
        self.source = source
        self.target = target
        self.result = .waiting
    }
}

/// Allows `MigrationFollowActivityPubEvent` to be encoded to and decoded from HTTP messages.
extension MigrationFollowActivityPubEvent: Content { }
