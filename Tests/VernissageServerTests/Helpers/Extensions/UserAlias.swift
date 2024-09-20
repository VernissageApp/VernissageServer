//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createUserAlias(userId: Int64, alias: String, activityPubProfile: String) async throws -> UserAlias {
        let id = await ApplicationManager.shared.generateId()
        let userAlias = UserAlias(id: id, userId: userId, alias: alias, activityPubProfile: activityPubProfile)
        _ = try await userAlias.save(on: self.db)
        return userAlias
    }
    
    func getUserAlias(id: Int64) async throws -> UserAlias? {
        return try await UserAlias.query(on: self.db)
            .filter(\.$id == id)
            .first()
    }
    
    func getUserAlias(alias: String) async throws -> UserAlias? {
        return try await UserAlias.query(on: self.db)
            .filter(\.$alias == alias)
            .first()
    }
}
