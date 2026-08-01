//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import ActivityPubKit
import Vapor

extension Application.Services {
    struct ActivityPubOutgoingMigrationServiceKey: StorageKey {
        typealias Value = ActivityPubOutgoingMigrationServiceType
    }

    var activityPubOutgoingMigrationService: ActivityPubOutgoingMigrationServiceType {
        get {
            self.application.storage[ActivityPubOutgoingMigrationServiceKey.self] ?? ActivityPubOutgoingMigrationService()
        }
        nonmutating set {
            self.application.storage[ActivityPubOutgoingMigrationServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ActivityPubOutgoingMigrationServiceType: Sendable {
    /// Sends a signed Follow or Undo Follow request created during an account migration.
    ///
    /// - Parameter request: The request containing the activity data, destination inbox, and signing key.
    /// - Throws: An error if the ActivityPub request cannot be created or delivered.
    func sendFollow(_ request: ActivityPubFollowRequestDto) async throws

    /// Sends a signed Move request created during an account migration.
    ///
    /// - Parameter request: The request containing the activity data, destination inbox, and signing key.
    /// - Throws: An error if the ActivityPub request cannot be created or delivered.
    func sendMove(_ request: ActivityPubMoveRequestDto) async throws
}

/// Sends signed Follow, Undo Follow and Move requests created during account migration.
final class ActivityPubOutgoingMigrationService: ActivityPubOutgoingMigrationServiceType {
    func sendFollow(_ request: ActivityPubFollowRequestDto) async throws {
        let activityPubClient = ActivityPubClient(privatePemKey: request.privateKey,
                                                  userAgent: Constants.userAgent,
                                                  host: request.sharedInbox.host)

        switch request.type {
        case .follow:
            try await activityPubClient.follow(request.target,
                                               by: request.source,
                                               on: request.sharedInbox,
                                               withId: request.id)
        case .unfollow:
            try await activityPubClient.unfollow(request.target,
                                                 by: request.source,
                                                 on: request.sharedInbox,
                                                 withId: request.id)
        }
    }

    func sendMove(_ request: ActivityPubMoveRequestDto) async throws {
        let activityPubClient = ActivityPubClient(privatePemKey: request.privateKey,
                                                  userAgent: Constants.userAgent,
                                                  host: request.sharedInbox.host)

        try await activityPubClient.move(request.source,
                                         to: request.target,
                                         on: request.sharedInbox,
                                         withId: request.id)
    }
}
