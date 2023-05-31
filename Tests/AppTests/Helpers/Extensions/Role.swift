@testable import App
import Vapor
import Fluent

extension Role {

    static func create(code: String,
                       title: String? = nil,
                       description: String? = nil,
                       hasSuperPrivileges: Bool = false,
                       isDefault: Bool = false) throws -> Role {

        let role = Role(code: code,
                        title: title ?? code,
                        description: description ?? code,
                        hasSuperPrivileges: hasSuperPrivileges,
                        isDefault: isDefault)

        try role.save(on: SharedApplication.application().db).wait()

        return role
    }

    static func get(code: String) throws -> Role {
        guard let role = try Role.query(on: SharedApplication.application().db).filter(\.$code == code).first().wait() else {
            throw SharedApplicationError.unwrap
        }

        return role
    }
}
