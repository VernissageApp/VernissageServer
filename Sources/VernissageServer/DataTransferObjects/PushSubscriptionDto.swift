//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's push subscription information.
struct PushSubscriptionDto {
    var id: String?

    /// Endpoint where new notifications should be send.
    var endpoint: String

    /// User agent public key. Base64 encoded string of a public key from a ECDH keypair using the prime256v1 curve.
    var userAgentPublicKey: String
    
    /// Auth secret. Base64 encoded string of 16 bytes of random data.
    var auth: String
    
    /// All notifications are enabled/disabled.
    var webPushNotificationsEnabled: Bool
    
    /// Notification when someone mentioned you in their status.
    var webPushMentionEnabled: Bool

    /// Notification when someone you enabled notifications for has posted a status.
    var webPushStatusEnabled: Bool

    /// Notification when someone boosted one of your statuses.
    var webPushReblogEnabled: Bool

    /// Notification when someone followed you.
    var webPushFollowEnabled: Bool

    /// Notification when someone requested to follow you.
    var webPushFollowRequestEnabled: Bool

    /// Notification when someone favourited one of your statuses.
    var webPushFavouriteEnabled: Bool

    /// Notification when status you boosted with has been edited.
    var webPushUpdateEnabled: Bool

    /// Notification when someone signed up (optionally sent to admins).
    var webPushAdminSignUpEnabled: Bool

    /// Notification when new report has been filed.
    var webPushAdminReportEnabled: Bool

    /// Notification when new comment to status has been added.
    var webPushNewCommentEnabled: Bool
    
    var createdAt: Date?
    var updatedAt: Date?
}

extension PushSubscriptionDto {
    init(from pushSubscription: PushSubscription) {
        self.id = pushSubscription.stringId() ?? ""
        self.endpoint = pushSubscription.endpoint
        self.userAgentPublicKey = pushSubscription.userAgentPublicKey
        self.auth = pushSubscription.auth
        self.webPushNotificationsEnabled = pushSubscription.webPushNotificationsEnabled
        self.webPushMentionEnabled = pushSubscription.webPushMentionEnabled
        self.webPushStatusEnabled = pushSubscription.webPushStatusEnabled
        self.webPushReblogEnabled = pushSubscription.webPushReblogEnabled
        self.webPushFollowEnabled = pushSubscription.webPushFollowEnabled
        self.webPushFollowRequestEnabled = pushSubscription.webPushFollowRequestEnabled
        self.webPushFavouriteEnabled = pushSubscription.webPushFavouriteEnabled
        self.webPushUpdateEnabled = pushSubscription.webPushUpdateEnabled
        self.webPushAdminSignUpEnabled = pushSubscription.webPushAdminSignUpEnabled
        self.webPushAdminReportEnabled = pushSubscription.webPushAdminReportEnabled
        self.webPushNewCommentEnabled = pushSubscription.webPushNewCommentEnabled
        self.createdAt = pushSubscription.createdAt
        self.updatedAt = pushSubscription.updatedAt
    }
    
    init(endpoint: String, userAgentPublicKey: String, auth: String) {
        self.endpoint = endpoint
        self.userAgentPublicKey = userAgentPublicKey
        self.auth = auth
        self.webPushNotificationsEnabled = true
        self.webPushMentionEnabled = true
        self.webPushStatusEnabled = true
        self.webPushReblogEnabled = true
        self.webPushFollowEnabled = true
        self.webPushFollowRequestEnabled = true
        self.webPushFavouriteEnabled = true
        self.webPushUpdateEnabled = true
        self.webPushAdminSignUpEnabled = true
        self.webPushAdminReportEnabled = true
        self.webPushNewCommentEnabled = true
    }
}

extension PushSubscriptionDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("endpoint", as: String.self, is: .url, required: true)
        validations.add("userAgentPublicKey", as: String.self, is: !.empty, required: true)
        validations.add("auth", as: String.self, is: !.empty, required: true)
    }
}

/// Allows `PushSubscriptionDto` to be encoded to and decoded from HTTP messages.
extension PushSubscriptionDto: Content { }
