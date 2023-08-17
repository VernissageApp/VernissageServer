//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class UserStatus: Model {
    static let schema: String = "UserStatuses"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?
    
    @Parent(key: "userId")
    var user: User

    @Parent(key: "statusId")
    var status: Status

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil, userId: Int64, statusId: Int64) {
        self.init()

        self.$user.id = userId
        self.$status.id = statusId
    }
}

/// Allows `UserStatus` to be encoded to and decoded from HTTP messages.
extension UserStatus: Content { }
