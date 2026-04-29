//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension Application.Services {
    struct ActivityPubProfileUpdateServiceKey: StorageKey {
        typealias Value = ActivityPubProfileUpdateServiceType
    }

    var activityPubProfileUpdateService: ActivityPubProfileUpdateServiceType {
        get {
            self.application.storage[ActivityPubProfileUpdateServiceKey.self] ?? ActivityPubProfileUpdateService()
        }
        nonmutating set {
            self.application.storage[ActivityPubProfileUpdateServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ActivityPubProfileUpdateServiceType: Sendable {
    /// Sends profile update as ActivityPub Update(Person) to remote mutual relationships of a local user.
    ///
    /// - Parameters:
    ///   - userId: The Id of the local user whose profile update should be sent.
    ///   - context: The execution context containing services and database access.
    /// - Throws: An error if preparing or sending updates fails.
    func send(userId: Int64, on context: ExecutionContext) async throws
}

final class ActivityPubProfileUpdateService: ActivityPubProfileUpdateServiceType {
    func send(userId: Int64, on context: ExecutionContext) async throws {
        let usersService = context.services.usersService
        let followsService = context.services.followsService
        let snowflakeService = context.services.snowflakeService

        guard let updatedUser = try await usersService.get(id: userId, on: context.db) else {
            context.logger.warning("Profile update cannot be sent. User '\(userId)' not found.")
            return
        }

        guard updatedUser.isLocal else {
            context.logger.warning("Profile update cannot be sent. User '\(userId)' is remote.")
            return
        }

        guard let privateKey = updatedUser.privateKey else {
            context.logger.warning("Profile update cannot be sent. Missing private key for user '\(userId)'.")
            return
        }

        let followersInboxes = try await followsService.getFollowersOfSharedInboxes(followersOf: userId, on: context)
        let followingInboxes = try await followsService.getFollowingOfSharedInboxes(followingBy: userId, on: context)
        let inboxes = Array(Set(followersInboxes).intersection(Set(followingInboxes)))

        guard inboxes.isEmpty == false else {
            context.logger.info("Profile update skipped. No mutual remote users for '\(updatedUser.userName)'.")
            return
        }

        let personDto = try await usersService.getPersonDto(for: updatedUser, on: context)
        let updateId = snowflakeService.generate()
        let published = updatedUser.updatedAt ?? Date()

        let inboxUrls = inboxes.compactMap { URL(string: $0) }

        for (index, inboxUrl) in inboxUrls.enumerated() {
            context.logger.info("[\(index + 1)/\(inboxUrls.count)] Sending profile update for '\(updatedUser.userName)' to inbox: '\(inboxUrl.absoluteString)'.")
            let activityPubClient = ActivityPubClient(privatePemKey: privateKey, userAgent: Constants.userAgent, host: inboxUrl.host)

            do {
                try await activityPubClient.update(person: personDto,
                                                   activityPubProfile: updatedUser.activityPubProfile,
                                                   on: inboxUrl,
                                                   withId: updateId,
                                                   published: published)
            } catch {
                await context.logger.store("Sending profile update to inbox error.", error, on: context.application)
            }
        }
    }
}
