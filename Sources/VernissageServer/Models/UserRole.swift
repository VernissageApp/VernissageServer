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
    var id: Int64?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?
    
    @Parent(key: "userId")
    var user: User

    @Parent(key: "roleId")
    var role: Role

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64?, userId: Int64, roleId: Int64) {
        self.init()

        self.$user.id = userId
        self.$role.id = roleId
    }
}

/// Allows `UserRole` to be encoded to and decoded from HTTP messages.
extension UserRole: Content { }
