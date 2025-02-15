//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createNotificationMarker(user: User, notification: VernissageServer.Notification) async throws -> NotificationMarker {
        let id = await ApplicationManager.shared.generateId()
        let notificationMarker = try NotificationMarker(id: id, notificationId: notification.requireID(), userId: user.requireID())
        _ = try await notificationMarker.save(on: self.db)
        return notificationMarker
    }
    
    func getNotificationMarker(user: User) async throws -> NotificationMarker? {
        return try await NotificationMarker.query(on: self.db)
            .filter(\.$user.$id == user.requireID())
            .with(\.$notification)
            .first()
    }
}

