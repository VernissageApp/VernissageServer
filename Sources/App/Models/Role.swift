import Fluent
import Vapor

final class Role: Model {

    static let schema = "Roles"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String

    @Field(key: "code")
    var code: String
    
    @Field(key: "description")
    var description: String?
    
    @Field(key: "hasSuperPrivileges")
    var hasSuperPrivileges: Bool
    
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
    
    init(id: UUID? = nil,
         code: String,
         title: String,
         description: String?,
         hasSuperPrivileges: Bool,
         isDefault: Bool
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.description = description
        self.hasSuperPrivileges = hasSuperPrivileges
        self.isDefault = isDefault
    }
}

/// Allows `Role` to be encoded to and decoded from HTTP messages.
extension Role: Content { }

extension Role {
    convenience init(from roleDto: RoleDto) {
        self.init(code: roleDto.code,
                  title: roleDto.title,
                  description: roleDto.description,
                  hasSuperPrivileges: roleDto.hasSuperPrivileges,
                  isDefault: roleDto.isDefault
        )
    }
}
