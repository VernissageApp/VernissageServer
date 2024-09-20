//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createInstanceBlockedDomain(domain: String) async throws -> InstanceBlockedDomain {
        let id = await ApplicationManager.shared.generateId()
        let instanceBlockedDomain = InstanceBlockedDomain(id: id, domain: domain, reason: "Blocked by unit tests.")
        _ = try await instanceBlockedDomain.save(on: self.db)
        return instanceBlockedDomain
    }
    
    func clearInstanceBlockedDomain() async throws {
        let all = try await InstanceBlockedDomain.query(on: self.db).all()
        try await all.delete(on: self.db)
    }
    
    func getInstanceBlockedDomain(id: Int64) async throws -> InstanceBlockedDomain? {
        return try await InstanceBlockedDomain.query(on: self.db)
            .filter(\.$id == id)
            .first()
    }
    
    func getInstanceBlockedDomain(domain: String) async throws -> InstanceBlockedDomain? {
        return try await InstanceBlockedDomain.query(on: self.db)
            .filter(\.$domain == domain)
            .first()
    }
}
