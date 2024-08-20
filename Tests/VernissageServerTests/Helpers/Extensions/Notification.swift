//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension VernissageServer.Notification {
    static func get(type: NotificationType, to userId: Int64, by byUserId: Int64, statusId: Int64?) async throws-> VernissageServer.Notification? {
        return try await VernissageServer.Notification.query(on: SharedApplication.application().db)
            .filter(\.$notificationType == type)
            .filter(\.$user.$id == userId)
            .filter(\.$byUser.$id == byUserId)
            .filter(\.$status.$id == statusId)
            .first()
    }
}
