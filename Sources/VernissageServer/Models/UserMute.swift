//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's mute.
final class UserMute: Model, @unchecked Sendable {
    static let schema: String = "UserMutes"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "muteStatuses")
    var muteStatuses: Bool
    
    @Field(key: "muteReblogs")
    var muteReblogs: Bool

    @Field(key: "muteNotifications")
    var muteNotifications: Bool
    
    @Field(key: "muteEnd")
    var muteEnd: Date?
    
    @Parent(key: "userId")
    var user: User
    
    @Parent(key: "mutedUserId")
    var mutedUser: User
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(
        id: Int64,
        userId: Int64,
        mutedUserId: Int64,
        muteStatuses: Bool,
        muteReblogs: Bool,
        muteNotifications: Bool,
        muteEnd: Date? = nil
    ) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.$mutedUser.id = mutedUserId

        self.muteStatuses = muteStatuses
        self.muteReblogs = muteReblogs
        self.muteNotifications = muteNotifications
        self.muteEnd = muteEnd
    }
}

/// Allows `UserMute` to be encoded to and decoded from HTTP messages.
extension UserMute: Content { }
