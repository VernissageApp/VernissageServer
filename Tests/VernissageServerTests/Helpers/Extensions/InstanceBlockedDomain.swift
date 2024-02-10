//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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
}
