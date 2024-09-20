//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createUserMute(userId: Int64, mutedUserId: Int64, muteStatuses: Bool, muteReblogs: Bool, muteNotifications: Bool) async throws -> UserMute {
        let id = await ApplicationManager.shared.generateId()
        let userMute = UserMute(
            id: id,
            userId: userId,
            mutedUserId: mutedUserId,
            muteStatuses: muteStatuses,
            muteReblogs: muteReblogs,
            muteNotifications: muteNotifications
        )

        _ = try await userMute.save(on: self.db)
        return userMute
    }
}

