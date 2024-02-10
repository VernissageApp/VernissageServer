//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension UserBlockedDomain {
    static func create(userId: Int64, domain: String) async throws -> UserBlockedDomain {
        let userBlockedDomain = UserBlockedDomain(userId: userId, domain: domain, reason: "Blocked by unit tests.")
        _ = try await userBlockedDomain.save(on: SharedApplication.application().db)
        return userBlockedDomain
    }
    
    static func clear() async throws {
        let all = try await UserBlockedDomain.query(on: SharedApplication.application().db).all()
        try await all.delete(on: SharedApplication.application().db)
    }
}
