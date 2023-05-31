import Vapor

struct RoleDto {
    var id: UUID?
    var code: String
    var title: String
    var description: String?
    var hasSuperPrivileges: Bool = false
    var isDefault: Bool = false
}

extension RoleDto {
    init(from role: Role) {
        self.init(
            id: role.id,
            code: role.code,
            title: role.title,
            description: role.description,
            hasSuperPrivileges: role.hasSuperPrivileges,
            isDefault: role.isDefault
        )
    }
}

extension RoleDto: Content { }

extension RoleDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: .count(...50))
        validations.add("code", as: String.self, is: .count(...20))
        validations.add("description", as: String?.self, is: .count(...200) || .nil, required: false)
    }
}
