//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension UserAlias {
    static func create(userId: Int64, alias: String, activityPubProfile: String) async throws -> UserAlias {
        let userAlias = UserAlias(userId: userId, alias: alias, activityPubProfile: activityPubProfile)
        _ = try await userAlias.save(on: SharedApplication.application().db)
        return userAlias
    }
    
    static func get(id: Int64) async throws -> UserAlias? {
        return try await UserAlias.query(on: SharedApplication.application().db)
            .filter(\.$id == id)
            .first()
    }
    
    static func get(alias: String) async throws -> UserAlias? {
        return try await UserAlias.query(on: SharedApplication.application().db)
            .filter(\.$alias == alias)
            .first()
    }
}
