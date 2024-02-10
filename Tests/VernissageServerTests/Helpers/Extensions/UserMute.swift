//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension UserMute {
    static func create(userId: Int64, mutedUserId: Int64, muteStatuses: Bool, muteReblogs: Bool, muteNotifications: Bool) async throws -> UserMute {
        let userMute = UserMute(
            userId: userId,
            mutedUserId: mutedUserId,
            muteStatuses: muteStatuses,
            muteReblogs: muteReblogs,
            muteNotifications: muteNotifications
        )

        _ = try await userMute.save(on: SharedApplication.application().db)
        return userMute
    }
}
