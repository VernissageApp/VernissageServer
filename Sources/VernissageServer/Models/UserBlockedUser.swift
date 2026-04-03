//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Users blocked by the user.
final class UserBlockedUser: Model, @unchecked Sendable {
    static let schema: String = "UserBlockedUsers"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "userId")
    var user: User
    
    @Parent(key: "blockedUserId")
    var blockedUser: User
    
    @Field(key: "reason")
    var reason: String?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, userId: Int64, blockedUserId: Int64, reason: String?) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.$blockedUser.id = blockedUserId
        self.reason = reason
    }
}

/// Allows `UserBlockedUser` to be encoded to and decoded from HTTP messages.
extension UserBlockedUser: Content { }
