//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's push subscription information.
final class PushSubscription: Model, @unchecked Sendable {

    static let schema = "PushSubscriptions"
    
    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    /// Endpoint where new notifications should be send.
    @Field(key: "endpoint")
    var endpoint: String

    /// User agent public key. Base64 encoded string of a public key from a ECDH keypair using the prime256v1 curve.
    @Field(key: "userAgentPublicKey")
    var userAgentPublicKey: String
    
    /// Auth secret. Base64 encoded string of 16 bytes of random data.
    @Field(key: "auth")
    var auth: String
    
    /// All notifications are enabled/disabled.
    @Field(key: "webPushNotificationsEnabled")
    var webPushNotificationsEnabled: Bool
    
    /// Notification when someone mentioned you in their status.
    @Field(key: "webPushMentionEnabled")
    var webPushMentionEnabled: Bool

    /// Notification when someone you enabled notifications for has posted a status.
    @Field(key: "webPushStatusEnabled")
    var webPushStatusEnabled: Bool

    /// Notification when someone boosted one of your statuses.
    @Field(key: "webPushReblogEnabled")
    var webPushReblogEnabled: Bool

    /// Notification when someone followed you.
    @Field(key: "webPushFollowEnabled")
    var webPushFollowEnabled: Bool

    /// Notification when someone requested to follow you.
    @Field(key: "webPushFollowRequestEnabled")
    var webPushFollowRequestEnabled: Bool

    /// Notification when someone favourited one of your statuses.
    @Field(key: "webPushFavouriteEnabled")
    var webPushFavouriteEnabled: Bool

    /// Notification when status you boosted with has been edited.
    @Field(key: "webPushUpdateEnabled")
    var webPushUpdateEnabled: Bool

    /// Notification when someone signed up (optionally sent to admins).
    @Field(key: "webPushAdminSignUpEnabled")
    var webPushAdminSignUpEnabled: Bool

    /// Notification when new report has been filed.
    @Field(key: "webPushAdminReportEnabled")
    var webPushAdminReportEnabled: Bool

    /// Notification when new comment to status has been added.
    @Field(key: "webPushNewCommentEnabled")
    var webPushNewCommentEnabled: Bool
    
    /// Ammount of errors received from push server.
    @Field(key: "ammountOfErrors")
    var ammountOfErrors: Int
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    @Parent(key: "userId")
    var user: User
    
    init() { }
    
    convenience init(id: Int64,
                     userId: Int64,
                     endpoint: String,
                     userAgentPublicKey: String,
                     auth: String,
                     webPushNotificationsEnabled: Bool = true,
                     webPushMentionEnabled: Bool = true,
                     webPushStatusEnabled: Bool = true,
                     webPushReblogEnabled: Bool = true,
                     webPushFollowEnabled: Bool = true,
                     webPushFollowRequestEnabled: Bool = true,
                     webPushFavouriteEnabled: Bool = true,
                     webPushUpdateEnabled: Bool = true,
                     webPushAdminSignUpEnabled: Bool = true,
                     webPushAdminReportEnabled: Bool = true,
                     webPushNewCommentEnabled: Bool = true
    ) {
        self.init()

        self.id = id
        self.endpoint = endpoint
        self.userAgentPublicKey = userAgentPublicKey
        self.auth = auth
        self.$user.id = userId
        self.ammountOfErrors = 0
        
        self.webPushNotificationsEnabled = webPushNotificationsEnabled
        self.webPushMentionEnabled = webPushMentionEnabled
        self.webPushStatusEnabled = webPushStatusEnabled
        self.webPushReblogEnabled = webPushReblogEnabled
        self.webPushFollowEnabled = webPushFollowEnabled
        self.webPushFollowRequestEnabled = webPushFollowRequestEnabled
        self.webPushFavouriteEnabled = webPushFavouriteEnabled
        self.webPushUpdateEnabled = webPushUpdateEnabled
        self.webPushAdminSignUpEnabled = webPushAdminSignUpEnabled
        self.webPushAdminReportEnabled = webPushAdminReportEnabled
        self.webPushNewCommentEnabled = webPushNewCommentEnabled
    }
}

extension PushSubscription {
    func isEnabled(type: NotificationType) -> Bool {
        guard self.webPushNotificationsEnabled else {
            return false
        }
        
        switch type {
        case .mention:
            return self.webPushMentionEnabled
        case .status:
            return self.webPushStatusEnabled
        case .reblog:
            return self.webPushReblogEnabled
        case .follow:
            return self.webPushFollowEnabled
        case .followRequest:
            return self.webPushFollowRequestEnabled
        case .favourite:
            return self.webPushFavouriteEnabled
        case .update:
            return self.webPushUpdateEnabled
        case .adminSignUp:
            return self.webPushAdminSignUpEnabled
        case .adminReport:
            return self.webPushAdminReportEnabled
        case .newComment:
            return self.webPushNewCommentEnabled
        }
    }
}

/// Allows `PushSubscription` to be encoded to and decoded from HTTP messages.
extension PushSubscription: Content { }
