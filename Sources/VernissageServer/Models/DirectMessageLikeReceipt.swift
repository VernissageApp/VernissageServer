//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Deduplication metadata for a remote private Like, retained after Undo until the message is deleted.
/// This is not a visible favourite; it also remembers Undo received before the corresponding Like.
final class DirectMessageLikeReceipt: Model, @unchecked Sendable {
    static let schema = "DirectMessageLikeReceipts"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "statusId")
    var status: Status

    @Parent(key: "userId")
    var user: User

    @Field(key: "activityPubId")
    var activityPubId: String

    @Field(key: "isUndone")
    var isUndone: Bool

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    init() { }

    convenience init(id: Int64, statusId: Int64, userId: Int64, activityPubId: String, isUndone: Bool) {
        self.init()
        self.id = id
        self.$status.id = statusId
        self.$user.id = userId
        self.activityPubId = activityPubId
        self.isUndone = isUndone
    }
}
