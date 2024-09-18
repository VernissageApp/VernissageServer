//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createRole(code: String,
                    title: String? = nil,
                    description: String? = nil,
                    isDefault: Bool = false) async throws -> Role {

        let role = Role(code: code,
                        title: title ?? code,
                        description: description ?? code,
                        isDefault: isDefault)

        try await role.save(on: self.db)

        return role
    }

    func getRole(code: String) async throws -> Role? {
        return try await Role.query(on: self.db).filter(\.$code == code).first()
    }
    
    func getRole(id: Int64) async throws -> Role? {
        return try await Role.query(on: self.db).filter(\.$id == id).first()
    }
}
