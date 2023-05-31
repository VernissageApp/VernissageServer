import Vapor
import Fluent

extension Application.Services {
    struct RolesServiceKey: StorageKey {
        typealias Value = RolesServiceType
    }

    var rolesService: RolesServiceType {
        get {
            self.application.storage[RolesServiceKey.self] ?? RolesService()
        }
        nonmutating set {
            self.application.storage[RolesServiceKey.self] = newValue
        }
    }
}

protocol RolesServiceType {
    func getDefault(on request: Request) async throws -> [Role]
    func validateCode(on request: Request, code: String, roleId: UUID?) async throws
}

final class RolesService: RolesServiceType {

    func getDefault(on request: Request) async throws-> [Role] {
        return try await Role.query(on: request.db).filter(\.$isDefault == true).all()
    }
    
    func validateCode(on request: Request, code: String, roleId: UUID?) async throws {
        if let unwrapedRoleId = roleId {
            
            let role = try await Role.query(on: request.db).group(.and) { verifyCodeGroup in
                verifyCodeGroup.filter(\.$code == code)
                verifyCodeGroup.filter(\.$id != unwrapedRoleId)
            }.first()
            
            if role != nil {
                throw RoleError.roleWithCodeExists
            }
        } else {
            let role = try await Role.query(on: request.db).filter(\.$code == code).first()
            if role != nil {
                throw RoleError.roleWithCodeExists
            }
        }
    }
}



