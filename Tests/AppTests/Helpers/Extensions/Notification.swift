//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Vapor
import Fluent

extension App.Notification {
    static func get(type: NotificationType, to userId: Int64, by byUserId: Int64, statusId: Int64?) async throws-> App.Notification? {
        guard let statusId else {
            return nil
        }
        
        return try await App.Notification.query(on: SharedApplication.application().db)
            .filter(\.$notificationType == type)
            .filter(\.$user.$id == userId)
            .filter(\.$byUser.$id == byUserId)
            .filter(\.$status.$id == statusId)
            .first()
    }
}
