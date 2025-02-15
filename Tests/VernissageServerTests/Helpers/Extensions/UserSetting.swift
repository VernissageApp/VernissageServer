//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Application {
    func createUserSetting(userId: Int64, key: String, value: String) async throws -> UserSetting {
        let id = await ApplicationManager.shared.generateId()
        let userSetting = UserSetting(id: id, userId: userId, key: key, value: value)
        _ = try await userSetting.save(on: self.db)
        return userSetting
    }
    
    func getAllUserSettings(userId: Int64) async throws -> [UserSetting] {
        return try await UserSetting.query(on: self.db)
            .filter(\.$user.$id == userId)
            .all()
    }
}
