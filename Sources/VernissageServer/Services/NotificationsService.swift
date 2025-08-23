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
protocol NotificationsServiceType: Sendable {
    /// Creates a new notification of a specific type for a user, optionally linked to statuses, and triggers web push notifications if enabled.
    ///
    /// - Parameters:
    ///   - type: The type of notification to create.
    ///   - user: The user who will receive the notification.
    ///   - byUserId: The Id of the user who triggers the notification.
    ///   - statusId: The Id of the related status (optional).
    ///   - mainStatusId: The Id of the main status for threads (optional).
    ///   - context: The execution context providing access to services, settings, and the database.
    /// - Throws: An error if notification creation or delivery fails.
    func create(type: NotificationType, to user: User, by byUserId: Int64, statusId: Int64?, mainStatusId: Int64?, on context: ExecutionContext) async throws
    
    /// Deletes a notification of a specific type between users and updates the notification marker if needed.
    ///
    /// - Parameters:
    ///   - type: The type of notification to delete.
    ///   - userId: The recipient user Id.
    ///   - byUserId: The sender user Id.
    ///   - statusId: The Id of the related status.
    ///   - database: The database connection to use.
    /// - Throws: An error if deletion fails.
    func delete(type: NotificationType, to userId: Int64, by byUserId: Int64, statusId: Int64, on database: Database) async throws
    
    /// Retrieves a paginated list of notifications for a user, supporting various filters and sorting.
    ///
    /// - Parameters:
    ///   - userId: The user Id for whom to retrieve notifications.
    ///   - linkableParams: Parameters for pagination, filtering, and sorting.
    ///   - database: The database connection to use.
    /// - Returns: An array of notifications.
    /// - Throws: An error if fetching notifications fails.
    func list(for userId: Int64, linkableParams: LinkableParams, on database: Database) async throws -> [Notification]
    
    /// Counts the number of unread notifications for a user and returns the current notification marker.
    ///
    /// - Parameters:
    ///   - userId: The user Id for whom to count notifications.
    ///   - database: The database connection to use.
    /// - Returns: A tuple containing the count and the notification marker (if present).
    /// - Throws: An error if counting notifications fails.
    func count(for userId: Int64, on database: Database) async throws -> (count: Int, marker: NotificationMarker?)
}

/// A service for managing notifications in the system.
final class NotificationsService: NotificationsServiceType {
    func create(type: NotificationType, to user: User, by byUserId: Int64, statusId: Int64?, mainStatusId: Int64?, on context: ExecutionContext) async throws {
        guard let notification = try await self.create(type: type, to: user, by: byUserId, statusId: statusId, mainStatusId: mainStatusId, on: context) else {
            return
        }
        
        // When WebPush are disabled we don't have to do nothing more.
        guard context.settings.cached?.isWebPushEnabled == true else {
            return
        }
        
        // Create object only when user wants to retrieve notification.
        let webPushes = try await self.createWebPushes(for: notification,
                                                       toUser: user,
                                                       byUserId: byUserId,
                                                       on: context.db)
        
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
                        mainStatusId: Int64?,
                        on context: ExecutionContext) async throws -> Notification? {
        // We have to add new notifications only for local users (remote users cannot sign in here).
        guard user.isLocal else {
            return nil
        }
        
        // We can add notifications only when user not muted notifications.
        let userMute = try await UserMute.query(on: context.db)
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
        let id = context.services.snowflakeService.generate()
        let notification = try Notification(id: id, notificationType: type, to: user.requireID(), by: byUserId, statusId: statusId, mainStatusId: mainStatusId)
        try await notification.save(on: context.db)
        
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
        
        // Id the notification exists in the NotificationMarkers table for the user, we need to change the marker for that user.
        if let notificationMarker = try await NotificationMarker.query(on: database)
            .filter(\.$user.$id == userId)
            .filter(\.$notification.$id == notification.requireID())
            .first() {

            // We have to download previous notification from user's notifications.
            if let previousNotification = try await Notification.query(on: database)
                .filter(\.$user.$id == userId)
                .filter(\.$id < notification.requireID())
                .sort(\.$id, .descending)
                .first(), let previousNotificationId = previousNotification.id {
                
                // Set previous notification in the marker.
                notificationMarker.$notification.id = previousNotificationId
                try await notificationMarker.save(on: database)
            } else {
                // There is not previous notifications, we have to delete marker.
                try await notificationMarker.delete(on: database)
            }
        }
            
        try await notification.delete(on: database)
    }
    
    func list(for userId: Int64, linkableParams: LinkableParams, on database: Database) async throws -> [Notification] {

        var query = Notification.query(on: database)
            .filter(\.$user.$id == userId)
            .with(\.$byUser) { byUser in
                byUser
                    .with(\.$flexiFields)
                    .with(\.$roles)
            }
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$originalHdrFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$mentions)
                .with(\.$category)
                .with(\.$user)
            }
            .with(\.$mainStatus) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$originalHdrFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$mentions)
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
