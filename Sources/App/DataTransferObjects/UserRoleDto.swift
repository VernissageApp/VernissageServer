import Vapor

struct UserRoleDto {
    var userId: UUID
    var roleId: UUID
}

extension UserRoleDto: Content { }
