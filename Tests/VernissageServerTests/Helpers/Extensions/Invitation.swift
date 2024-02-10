//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Invitation {
    static func create(userId: Int64) async throws -> Invitation {
        let invitation = Invitation(userId: userId)
        _ = try await invitation.save(on: SharedApplication.application().db)
        return invitation
    }
    
    static func getAll(userId: Int64) async throws -> [Invitation] {
        return try await Invitation.query(on: SharedApplication.application().db)
            .filter(\.$user.$id == userId)
            .all()
    }
    
    func set(invitedId: Int64) async throws {
        self.$invited.id = invitedId
        try await self.save(on: SharedApplication.application().db)
    }
}
