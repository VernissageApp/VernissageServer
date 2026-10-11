//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Status favourite.
final class StatusFavourite: Model, @unchecked Sendable {
    static let schema: String = "StatusFavourites"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "statusId")
    var status: Status

    @Parent(key: "userId")
    var user: User

    /// Original remote Like identifier. An Undo must refer to this Like, rather than a later re-like.
    @OptionalField(key: "activityPubId")
    var activityPubId: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, statusId: Int64, userId: Int64, activityPubId: String? = nil) {
        self.init()

        self.id = id
        self.$status.id = statusId
        self.$user.id = userId
        self.activityPubId = activityPubId
    }
}

/// Allows `StatusFavourite` to be encoded to and decoded from HTTP messages.
extension StatusFavourite: Content { }
