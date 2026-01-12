//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createUserBlockedDomain(userId: Int64, domain: String) async throws -> UserBlockedDomain {
        let id = await ApplicationManager.shared.generateId()
        let userBlockedDomain = UserBlockedDomain(id: id, userId: userId, domain: domain, reason: "Blocked by unit tests.")
        _ = try await userBlockedDomain.save(on: self.db)
        return userBlockedDomain
    }
    
    func clearUserBlockedDomain() async throws {
        let all = try await UserBlockedDomain.query(on: self.db).all()
        try await all.delete(on: self.db)
    }
    
    func getUserBlockedDomain(id: Int64) async throws -> UserBlockedDomain? {
        return try await UserBlockedDomain.query(on: self.db)
            .filter(\.$id == id)
            .first()
    }
    
    func getUserBlockedDomain(domain: String) async throws -> UserBlockedDomain? {
        return try await UserBlockedDomain.query(on: self.db)
            .filter(\.$domain == domain)
            .first()
    }
}
