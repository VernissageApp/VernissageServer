//
//  File.swift
//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTVapor
import Fluent

extension Invitation {
    static func create(userId: UInt64) async throws -> Invitation {
        let invitation = Invitation(userId: userId)
        _ = try await invitation.save(on: SharedApplication.application().db)
        return invitation
    }
    
    func set(invitedId: UInt64) async throws {
        self.$invited.id = invitedId
        try await self.save(on: SharedApplication.application().db)
    }
}
