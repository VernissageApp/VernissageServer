//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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

protocol NotificationsServiceType {
    func create(type: NotificationType, to user: User, by byUserId: Int64, statusId: Int64?, on database: Database) async throws
    func delete(type: NotificationType, to userId: Int64, by byUserId: Int64, statusId: Int64, on database: Database) async throws
    func list(on database: Database, for userId: Int64, minId: String?, maxId: String?, sinceId: String?, limit: Int) async throws -> [Notification]
}

final class NotificationsService: NotificationsServiceType {
    func create(type: NotificationType, to user: User, by byUserId: Int64, statusId: Int64?, on database: Database) async throws {
        // We have to add new notifications only for local users (remote users cannot sign in here).
        guard user.isLocal else {
            return
        }
        
        let notification = try Notification(notificationType: type, to: user.requireID(), by: byUserId, statusId: statusId)
        try await notification.save(on: database)
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
    
    func list(on database: Database,
              for userId: Int64,
              minId: String? = nil,
              maxId: String? = nil,
              sinceId: String? = nil,
              limit: Int = 40) async throws -> [Notification] {

        var query = Notification.query(on: database)
            .filter(\.$user.$id == userId)
            .with(\.$byUser)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$user)
            }
        
        
        if let minId = minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let notifications = try await query
            .limit(limit)
            .all()

        return notifications.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
    }
}
