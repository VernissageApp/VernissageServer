//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit
import Queues

extension Application.Services {
    struct NotificationsServiceKey: StorageKey {
        typealias Value = NotificationsServiceType
    }

    var notificationsService: NotificationsServiceType {
        get {
            self.application.storage[NotificationsServiceKey.self] ?? NotificationsService()
        }
        nonmutating set {
            self.application.storage[NotificationsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol NotificationsServiceType {
    func create(type: NotificationType, to user: User, by byUserId: Int64, statusId: Int64?, on request: Request) async throws
    func create(type: NotificationType, to user: User, by byUserId: Int64, statusId: Int64?, on context: QueueContext) async throws
    func delete(type: NotificationType, to userId: Int64, by byUserId: Int64, statusId: Int64, on database: Database) async throws
    func list(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> [Notification]
    func count(for userId: Int64, on database: Database) async throws -> (count: Int, marker: NotificationMarker?)
}

/// A service for managing notifications in the system.
final class NotificationsService: NotificationsServiceType {
    func create(type: NotificationType, to user: User, by byUserId: Int64, statusId: Int64?, on request: Request) async throws {
        guard let notification = try await self.create(type: type, to: user, by: byUserId, statusId: statusId, on: request.db) else {
            return
        }
        
        // When WebPush are disabled we don't have to do nothing more.
        guard request.application.settings.cached?.isWebPushEnabled == true else {
            return
        }
        
        // Create object only when user want's to retrieve notification.
        let webPushes = try await self.createWebPushes(for: notification,
                                                       toUser: user,
                                                       byUserId: byUserId,
                                                       on: request.db)
        
        // When notifications has been added to database and webpush object has been created we can send it to the user's device.
        for webPush in webPushes {
            try await request
                .queues(.webPush)
                .dispatch(WebPushSenderJob.self, webPush, maxRetryCount: 3)
        }
    }
    
    func create(type: NotificationType, to user: User, by byUserId: Int64, statusId: Int64?, on context: QueueContext) async throws {
        guard let notification = try await self.create(type: type, to: user, by: byUserId, statusId: statusId, on: context.application.db) else {
            return
        }
        
        // When WebPush are disabled we don't have to do nothing more.
        guard context.application.settings.cached?.isWebPushEnabled == true else {
            return
        }

        // Create object only when user want's to retrieve notification.
        let webPushes = try await self.createWebPushes(for: notification,
                                                       toUser: user,
                                                       byUserId: byUserId,
                                                       on: context.application.db)
        
        // When notifications has been added to database and webpush object has been created we can send it to the user's device.
        for webPush in webPushes {
            try await context
                .queues(.webPush)
                .dispatch(WebPushSenderJob.self, webPush, maxRetryCount: 3)
        }
    }
    
    private func create(type: NotificationType,
                        to user: User,
                        by byUserId: Int64,
                        statusId: Int64?,
                        on database: Database) async throws -> Notification? {
        // We have to add new notifications only for local users (remote users cannot sign in here).
        guard user.isLocal else {
            return nil
        }
        
        // We can add notifications only when user not muted notifications.
        let userMute = try await UserMute.query(on: database)
            .filter(\.$user.$id == user.requireID())
            .filter(\.$mutedUser.$id == byUserId)
            .group(.or) { group in
                group
                    .filter(\.$muteEnd == nil)
                    .filter(\.$muteEnd > Date())
            }.first()
        
        if userMute?.muteNotifications == true {
            return nil
        }
        
        // Save notification to database.
        let notification = try Notification(notificationType: type, to: user.requireID(), by: byUserId, statusId: statusId)
        try await notification.save(on: database)
        
        return notification
    }
    
    func delete(type: NotificationType, to userId: Int64, by byUserId: Int64, statusId: Int64, on database: Database) async throws {
        guard let notification = try await Notification.query(on: database)
            .filter(\.$notificationType == type)
            .filter(\.$user.$id == userId)
            .filter(\.$byUser.$id == byUserId)
            .filter(\.$status.$id == statusId)
            .first() else {
            return
        }
            
        try await notification.delete(on: database)
    }
    
    func list(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> [Notification] {

        var query = Notification.query(on: database)
            .filter(\.$user.$id == userId)
            .with(\.$byUser)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$category)
                .with(\.$user)
            }
        
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let notifications = try await query
            .limit(linkableParams.limit)
            .all()

        return notifications.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
    }
    
    private func createWebPushes(for notification: Notification, toUser user: User, byUserId: Int64, on database: Database) async throws -> [WebPush] {
        let pushSubscriptions = try await PushSubscription.query(on: database)
            .filter(\.$user.$id == user.requireID())
            .all()
        
        var webPushes: [WebPush] = []
        for pushSubscription in pushSubscriptions {
            guard pushSubscription.isEnabled(type: notification.notificationType) else {
                continue
            }
            
            try webPushes.append(WebPush(fromUserId: byUserId,
                                         toUserId: user.requireID(),
                                         pushSubscriptionId: pushSubscription.requireID(),
                                         notificationType: notification.notificationType))
        }
        
        return webPushes
    }
    
    func count(for userId: Int64, on database: Database) async throws -> (count: Int, marker: NotificationMarker?) {
        guard let marker = try await NotificationMarker.query(on: database)
            .filter(\.$user.$id == userId)
            .with(\.$notification)
            .first() else {
            return (count: 0, marker: nil)
        }

        let count = try await Notification.query(on: database)
            .filter(\.$user.$id == userId)
            .filter(\.$id > marker.$notification.id)
            .count()
        
        return (count: count, marker: marker)
    }
}
