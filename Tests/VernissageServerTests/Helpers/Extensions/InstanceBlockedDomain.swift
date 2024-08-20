//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension InstanceBlockedDomain {
    static func create(domain: String) async throws -> InstanceBlockedDomain {
        let instanceBlockedDomain = InstanceBlockedDomain(domain: domain, reason: "Blocked by unit tests.")
        _ = try await instanceBlockedDomain.save(on: SharedApplication.application().db)
        return instanceBlockedDomain
    }
    
    static func clear() async throws {
        let all = try await InstanceBlockedDomain.query(on: SharedApplication.application().db).all()
        try await all.delete(on: SharedApplication.application().db)
    }
    
    static func get(id: Int64) async throws -> InstanceBlockedDomain? {
        return try await InstanceBlockedDomain.query(on: SharedApplication.application().db)
            .filter(\.$id == id)
            .first()
    }
    
    static func get(domain: String) async throws -> InstanceBlockedDomain? {
        return try await InstanceBlockedDomain.query(on: SharedApplication.application().db)
            .filter(\.$domain == domain)
            .first()
    }
}
