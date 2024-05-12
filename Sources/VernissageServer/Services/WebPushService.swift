//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues

extension Application.Services {
    struct WebPushServiceKey: StorageKey {
        typealias Value = WebPushServiceType
    }

    var webPushService: WebPushServiceType {
        get {
            self.application.storage[WebPushServiceKey.self] ?? WebPushService()
        }
        nonmutating set {
            self.application.storage[WebPushServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol WebPushServiceType {
    func send(webPush: WebPush, on context: QueueContext) async throws
}

/// A service for sending WebPush messages.
final class WebPushService: WebPushServiceType {
    func send(webPush: WebPush, on context: QueueContext) async throws {
        guard let pushSubscription = try await PushSubscription.find(webPush.pushSubscriptionId, on: context.application.db) else {
            context.logger.warning("[WebPush] Push subscription: '\(webPush.pushSubscriptionId)' not found.")
            return
        }
        
        guard let fromUser = try await User.find(webPush.fromUserId, on: context.application.db) else {
            context.logger.warning("[WebPush] From user: '\(webPush.fromUserId)' not found.")
            return
        }
        
        guard let toUser = try await User.find(webPush.toUserId, on: context.application.db) else {
            context.logger.warning("[WebPush] To user: '\(webPush.toUserId)' not found.")
            return
        }
        
        guard let appplicationSettings = context.application.settings.cached else {
            context.logger.warning("[WebPush] System settings not cached.")
            return
        }
        
        let baseAddress = context.application.settings.cached?.baseAddress ?? ""
        
        let notificationsService = context.application.services.notificationsService
        let (count, _) = try await notificationsService.count(for: toUser.requireID(), on: context.application.db)
        
        let webPushDto = WebPushDto(vapidSubject: appplicationSettings.webPushVapidSubject,
                                    vapidPublicKey: appplicationSettings.webPushVapidPublicKey,
                                    vapidPrivateKey: appplicationSettings.webPushVapidPrivateKey,
                                    endpoint: pushSubscription.endpoint,
                                    userAgentPublicKey: pushSubscription.userAgentPublicKey,
                                    auth: pushSubscription.auth,
                                    title: self.notificationTitle(notificationType: webPush.notificationType),
                                    body: self.notificationBody(notificationType: webPush.notificationType, fromUser: fromUser),
                                    icon: "\(baseAddress)/assets/icons/icon-1024x1024.png",
                                    badgeCount: count
        )
        
        // Send new WebPush to service responsible for resending WebPush messages to user devices.
        context.logger.info("[WebPush] Sending push notification to: '\(toUser.userName)', push subscription: '\(webPush.pushSubscriptionId)'.")
        let webPushEndpointUrl = URI(string: appplicationSettings.webPushEndpoint)
        
        let result = try await context.application.client.post(webPushEndpointUrl) { request in
            // Encode JSON to the request body.
            try request.content.encode(webPushDto)

            // Add auth header to the request
            request.headers.replaceOrAdd(name: "Authorization", value: "Basic \(appplicationSettings.webPushSecretKey)")
        }
        
        if result.status != .created {
            context.logger.warning("[WebPush] Error response from webpush service, status: '\(result.status.description)', body: '\(result.bodyValue)'.")
            
            if result.status == .failedDependency {
                // When we cannot send a notification few times then we have to remove PushSubscription entity from database.
                if pushSubscription.ammountOfErrors > 10 {
                    try await pushSubscription.delete(on: context.application.db)
                } else {
                    pushSubscription.ammountOfErrors = pushSubscription.ammountOfErrors + 1
                    try await pushSubscription.save(on: context.application.db)
                }
            }
        }
    }
    
    func notificationTitle(notificationType: NotificationType) -> String {
        switch notificationType {
        case .mention:
            return "New mention"
        case .status:
            return "New status"
        case .reblog:
            return "New reblog"
        case .follow:
            return "New follower"
        case .followRequest:
            return "New follow request"
        case .favourite:
            return "New favourite"
        case .update:
            return "New status update"
        case .adminSignUp:
            return "New user sign up"
        case .adminReport:
            return "New report"
        case .newComment:
            return "New comment"
        }
    }
    
    func notificationBody(notificationType: NotificationType, fromUser: User) -> String {
        switch notificationType {
        case .mention:
            return "\(fromUser.name ?? fromUser.userName) mentioned you."
        case .status:
            return "\(fromUser.name ?? fromUser.userName) published new status."
        case .reblog:
            return "\(fromUser.name ?? fromUser.userName) reblogged your status."
        case .follow:
            return "\(fromUser.name ?? fromUser.userName) followed you."
        case .followRequest:
            return "You have new follow request from \(fromUser.name ?? fromUser.userName)."
        case .favourite:
            return "\(fromUser.name ?? fromUser.userName) favourited your status."
        case .update:
            return "\(fromUser.name ?? fromUser.userName) updated his status."
        case .adminSignUp:
            return "\(fromUser.name ?? fromUser.userName) created account in the system."
        case .adminReport:
            return "\(fromUser.name ?? fromUser.userName) created a new report."
        case .newComment:
            return "\(fromUser.name ?? fromUser.userName) added a comment to your status."
        }
    }
}
