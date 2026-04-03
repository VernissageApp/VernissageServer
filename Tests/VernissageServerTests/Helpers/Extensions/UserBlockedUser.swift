//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createUserBlockedUser(userId: Int64, blockedUserId: Int64, reason: String) async throws -> UserBlockedUser {
        let id = await ApplicationManager.shared.generateId()
        let userBlockedUser = UserBlockedUser(id: id, userId: userId, blockedUserId: blockedUserId, reason: reason)

        _ = try await userBlockedUser.save(on: self.db)
        return userBlockedUser
    }
}

