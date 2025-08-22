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
    /// Mutes a specific user.
    /// - Parameters:
    ///   - userId: The identifier of the user performing the mute.
    ///   - mutedUserId: The identifier of the user being muted.
    ///   - muteStatuses: Whether to mute statuses from the user.
    ///   - muteReblogs: Whether to mute reblogs from the user.
    ///   - muteNotifications: Whether to mute notifications from the user.
    ///   - muteEnd: Optional end date for the mute.
    ///   - request: The request context.
    /// - Returns: ``UserMute`` object representing the mute.
    /// - Throws: Database errors.
    func mute(userId: Int64, mutedUserId: Int64, muteStatuses: Bool, muteReblogs: Bool, muteNotifications: Bool, muteEnd: Date?, on request: Request) async throws -> UserMute

    /// Unmutes a specific user.
    /// - Parameters:
    ///   - userId: The identifier of the user performing the unmute.
    ///   - mutedUserId: The identifier of the user being unmuted.
    ///   - request: The request context.
    /// - Throws: Database errors.
    func unmute(userId: Int64, mutedUserId: Int64, on request: Request) async throws
}

/// A service for managing user mutes.
final class UserMutesService: UserMutesServiceType {

    func mute(userId: Int64, mutedUserId: Int64, muteStatuses: Bool, muteReblogs: Bool, muteNotifications: Bool, muteEnd: Date? = nil, on request: Request) async throws -> UserMute {
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
    
    func unmute(userId: Int64, mutedUserId: Int64, on request: Request) async throws {
        guard let userMute = try await UserMute.query(on: request.db)
            .filter(\.$user.$id == userId)
            .filter(\.$mutedUser.$id == mutedUserId)
            .first() else {
            return
        }
        
        try await userMute.delete(on: request.db)
    }
}
