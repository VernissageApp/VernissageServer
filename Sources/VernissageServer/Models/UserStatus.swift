//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User statuses (for home timeline).
final class UserStatus: Model, @unchecked Sendable {
    static let schema: String = "UserStatuses"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "userStatusType")
    var userStatusType: UserStatusType
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?
    
    @Parent(key: "userId")
    var user: User

    @Parent(key: "statusId")
    var status: Status

    init() { }

    convenience init(id: Int64, type userStatusType: UserStatusType, userId: Int64, statusId: Int64) {
        self.init()

        self.id = id
        self.userStatusType = userStatusType
        self.$user.id = userId
        self.$status.id = statusId
    }
}

/// Allows `UserStatus` to be encoded to and decoded from HTTP messages.
extension UserStatus: Content { }
