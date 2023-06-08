//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class UserRole: Model {
    static let schema: String = "UserRoles"

    @ID(custom: .id, generatedBy: .user)
    var id: UInt64?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?
    
    @Parent(key: "userId")
    var user: User

    @Parent(key: "roleId")
    var role: Role

    init() {}

    init(id: UInt64?, userId: UInt64, roleId: UInt64) {
        self.id = id ?? Frostflake.generate()
        self.$user.id = userId
        self.$role.id = roleId
    }
}

/// Allows `UserRole` to be encoded to and decoded from HTTP messages.
extension UserRole: Content { }
