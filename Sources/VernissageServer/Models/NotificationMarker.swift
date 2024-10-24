//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Last notification read by user.
final class NotificationMarker: Model, @unchecked Sendable {
    static let schema: String = "NotificationMarkers"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Parent(key: "notificationId")
    var notification: Notification

    @Parent(key: "userId")
    var user: User
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, notificationId: Int64, userId: Int64) {
        self.init()

        self.id = id
        self.$notification.id = notificationId
        self.$user.id = userId
    }
}

/// Allows `NotificationMarker` to be encoded to and decoded from HTTP messages.
extension NotificationMarker: Content { }

