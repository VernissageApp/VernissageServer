//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User role.
final class Role: Model, @unchecked Sendable {

    static let schema = "Roles"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "title")
    var title: String

    @Field(key: "code")
    var code: String
    
    @Field(key: "description")
    var description: String?
    
    @Field(key: "isDefault")
    var isDefault: Bool
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deletedAt", on: .delete)
    var deletedAt: Date?
    
    @Siblings(through: UserRole.self, from: \.$role, to: \.$user)
    var users: [User]

    init() { }
    
    convenience init(id: Int64,
                     code: String,
                     title: String,
                     description: String?,
                     isDefault: Bool
    ) {
        self.init()

        self.id = id
        self.code = code
        self.title = title
        self.description = description
        self.isDefault = isDefault
    }
}

/// Allows `Role` to be encoded to and decoded from HTTP messages.
extension Role: Content { }

extension Role {
    convenience init(from roleDto: RoleDto, withId id: Int64) {
        self.init(id: id,
                  code: roleDto.code,
                  title: roleDto.title,
                  description: roleDto.description,
                  isDefault: roleDto.isDefault
        )
    }
}

extension Role {
    static let administrator = "administrator"
    static let moderator = "moderator"
    static let member = "member"
}
