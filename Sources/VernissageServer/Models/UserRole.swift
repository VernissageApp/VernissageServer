//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's role.
final class UserRole: Model, @unchecked Sendable {
    static let schema: String = "UserRoles"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?
    
    @Parent(key: "userId")
    var user: User

    @Parent(key: "roleId")
    var role: Role

    init() { }

    convenience init(id: Int64, userId: Int64, roleId: Int64) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.$role.id = roleId
    }
}

/// Allows `UserRole` to be encoded to and decoded from HTTP messages.
extension UserRole: Content { }
