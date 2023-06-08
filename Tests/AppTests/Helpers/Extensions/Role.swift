//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Vapor
import Fluent

extension Role {

    static func create(code: String,
                       title: String? = nil,
                       description: String? = nil,
                       hasSuperPrivileges: Bool = false,
                       isDefault: Bool = false) async throws -> Role {

        let role = Role(code: code,
                        title: title ?? code,
                        description: description ?? code,
                        hasSuperPrivileges: hasSuperPrivileges,
                        isDefault: isDefault)

        try await role.save(on: SharedApplication.application().db)

        return role
    }

    static func get(code: String) async throws -> Role {
        guard let role = try await Role.query(on: SharedApplication.application().db).filter(\.$code == code).first() else {
            throw SharedApplicationError.unwrap
        }

        return role
    }
}
