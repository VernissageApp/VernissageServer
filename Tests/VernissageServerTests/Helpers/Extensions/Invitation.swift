//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Application {
    func createInvitation(userId: Int64) async throws -> Invitation {
        let id = await ApplicationManager.shared.generateId()
        let invitation = Invitation(id: id, userId: userId)
        _ = try await invitation.save(on: self.db)
        return invitation
    }
    
    func getAllInvitations(userId: Int64) async throws -> [Invitation] {
        return try await Invitation.query(on: self.db)
            .filter(\.$user.$id == userId)
            .all()
    }
    
    func set(invitation: Invitation, invitedId: Int64) async throws {
        invitation.$invited.id = invitedId
        try await invitation.save(on: self.db)
    }
}
