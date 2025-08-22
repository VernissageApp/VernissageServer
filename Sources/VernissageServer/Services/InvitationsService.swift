//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct InvitationsServiceKey: StorageKey {
        typealias Value = InvitationsServiceType
    }

    var invitationsService: InvitationsServiceType {
        get {
            self.application.storage[InvitationsServiceKey.self] ?? InvitationsService()
        }
        nonmutating set {
            self.application.storage[InvitationsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol InvitationsServiceType: Sendable {
    /// Retrieves an invitation by its unique code.
    ///
    /// - Parameters:
    ///   - code: The unique invitation code to look up.
    ///   - database: The database connection to use.
    /// - Returns: The invitation if found, or nil if not found.
    /// - Throws: An error if the database query fails.
    func get(by code: String, on database: Database) async throws -> Invitation?

    /// Marks an invitation as used by associating it with a user.
    ///
    /// - Parameters:
    ///   - code: The invitation code to use.
    ///   - user: The user who uses the invitation.
    ///   - database: The database connection to use.
    /// - Throws: An error if the database update fails.
    func use(code: String, for user: User, on database: Database) async throws
}

/// A service for managing invitations to the system.
final class InvitationsService: InvitationsServiceType {
    func get(by code: String, on database: Database) async throws -> Invitation? {
        return try await Invitation.query(on: database).filter(\.$code == code).first()
    }
    
    func use(code: String, for user: User, on database: Database) async throws {
        if let invitation = try await self.get(by: code, on: database) {
            invitation.$invited.id = user.id
            try await invitation.save(on: database)
        }
    }
}
