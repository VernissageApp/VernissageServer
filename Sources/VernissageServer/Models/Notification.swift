//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User notification.
final class Notification: Model, @unchecked Sendable {
    static let schema: String = "Notifications"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "notificationType")
    var notificationType: NotificationType
    
    @Parent(key: "userId")
    var user: User
    
    @Parent(key: "byUserId")
    var byUser: User
    
    @OptionalParent(key: "statusId")
    var status: Status?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    convenience init(id: Int64, notificationType: NotificationType, to userId: Int64, by byUserId: Int64,  statusId: Int64? = nil) {
        self.init()

        self.id = id
        self.notificationType = notificationType
        self.$user.id = userId
        self.$byUser.id = byUserId
        self.$status.id = statusId
    }
}

/// Allows `Notification` to be encoded to and decoded from HTTP messages.
extension Notification: Content { }
