//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Vapor
import Fluent

extension NotificationMarker {
    static func create(user: User, notification: App.Notification) async throws -> NotificationMarker {
        let notificationMarker = try NotificationMarker(notificationId: notification.requireID(), userId: user.requireID())
        _ = try await notificationMarker.save(on: SharedApplication.application().db)
        return notificationMarker
    }
    
    static func get(user: User) async throws -> NotificationMarker? {
        return try await NotificationMarker.query(on: SharedApplication.application().db)
            .filter(\.$user.$id == user.requireID())
            .with(\.$notification)
            .first()
    }
}

