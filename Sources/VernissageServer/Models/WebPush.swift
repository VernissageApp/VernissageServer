//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Vapor

/// Entity that holds information about WebPush notification.
@_documentation(visibility: private)
struct WebPush {
    /// User id who send notification.
    var fromUserId: Int64
    
    /// User id who retrieve notification.
    var toUserId: Int64
    
    /// Push subscription id.
    var pushSubscriptionId: Int64
    
    /// Type of notification.
    var notificationType: NotificationType
}

extension WebPush {
    init?(from notification: Notification, pushSubscriptionId: Int64) throws {
        self.fromUserId = try notification.byUser.requireID()
        self.toUserId = try notification.user.requireID()
        self.pushSubscriptionId = pushSubscriptionId
        self.notificationType = notification.notificationType
    }
}

/// Allows `WebPush` to be encoded to and decoded from HTTP messages.
extension WebPush: Content { }
