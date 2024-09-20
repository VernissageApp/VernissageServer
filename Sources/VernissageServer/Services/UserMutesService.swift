//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct UserMutesServiceKey: StorageKey {
        typealias Value = UserMutesServiceType
    }

    var userMutesService: UserMutesServiceType {
        get {
            self.application.storage[UserMutesServiceKey.self] ?? UserMutesService()
        }
        nonmutating set {
            self.application.storage[UserMutesServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol UserMutesServiceType: Sendable {
    func mute(on request: Request, userId: Int64, mutedUserId: Int64, muteStatuses: Bool, muteReblogs: Bool, muteNotifications: Bool, muteEnd: Date?) async throws -> UserMute
    func unmute(on request: Request, userId: Int64, mutedUserId: Int64) async throws
}

/// A service for managing user mutes.
final class UserMutesService: UserMutesServiceType {

    func mute(on request: Request, userId: Int64, mutedUserId: Int64, muteStatuses: Bool, muteReblogs: Bool, muteNotifications: Bool, muteEnd: Date? = nil) async throws -> UserMute {
        if let userMute = try await UserMute.query(on: request.db)
            .filter(\.$user.$id == userId)
            .filter(\.$mutedUser.$id == mutedUserId)
            .first() {
            
            userMute.muteStatuses = muteStatuses
            userMute.muteReblogs = muteReblogs
            userMute.muteNotifications = muteNotifications
            userMute.muteEnd = muteEnd
            
            try await userMute.save(on: request.db)
            return userMute
        } else {
            let newUserMuteId = request.application.services.snowflakeService.generate()
            let userMute = UserMute(
                id: newUserMuteId,
                userId: userId,
                mutedUserId: mutedUserId,
                muteStatuses: muteStatuses,
                muteReblogs: muteReblogs,
                muteNotifications: muteNotifications,
                muteEnd: muteEnd
            )
            
            try await userMute.save(on: request.db)
            return userMute
        }
    }
    
    func unmute(on request: Request, userId: Int64, mutedUserId: Int64) async throws {
        guard let userMute = try await UserMute.query(on: request.db)
            .filter(\.$user.$id == userId)
            .filter(\.$mutedUser.$id == mutedUserId)
            .first() else {
            return
        }
        
        try await userMute.delete(on: request.db)
    }
}
