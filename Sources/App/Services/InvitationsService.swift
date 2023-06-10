//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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

protocol InvitationsServiceType {
    func get(by code: String, on request: Request) async throws -> Invitation?
    func use(code: String, on request: Request, for user: User) async throws
}

final class InvitationsService: InvitationsServiceType {
    func get(by code: String, on request: Request) async throws -> Invitation? {
        return try await Invitation.query(on: request.db).filter(\.$code == code).first()
    }
    
    func use(code: String, on request: Request, for user: User) async throws {
        if let invitation = try await self.get(by: code, on: request) {
            invitation.$invited.id = user.id
            try await invitation.save(on: request.db)
        }
    }
}
