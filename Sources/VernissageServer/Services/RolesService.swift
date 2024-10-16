//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

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

@_documentation(visibility: private)
protocol RolesServiceType: Sendable {
    func getDefault(on database: Database) async throws -> [Role]
}

/// A service for managing roles in the system.
final class RolesService: RolesServiceType {
    func getDefault(on database: Database) async throws -> [Role] {
        return try await Role.query(on: database).filter(\.$isDefault == true).all()
    }
}
