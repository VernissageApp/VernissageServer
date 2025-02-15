//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func getNotification(type: NotificationType, to userId: Int64, by byUserId: Int64, statusId: Int64?) async throws-> VernissageServer.Notification? {
        return try await VernissageServer.Notification.query(on: self.db)
            .filter(\.$notificationType == type)
            .filter(\.$user.$id == userId)
            .filter(\.$byUser.$id == byUserId)
            .filter(\.$status.$id == statusId)
            .first()
    }
}
