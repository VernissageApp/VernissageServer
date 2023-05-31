import Fluent
import Vapor

final class UserRole: Model {
    static let schema: String = "UserRoles"

    @ID(key: .id)
    var id: UUID?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?
    
    @Parent(key: "userId")
    var user: User

    @Parent(key: "roleId")
    var role: Role

    init() {}

    init(userId: UUID, roleId: UUID) {
        self.$user.id = userId
        self.$role.id = roleId
    }
}

/// Allows `UserRole` to be encoded to and decoded from HTTP messages.
extension UserRole: Content { }
