//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct ClearDeletedUsersServiceKey: StorageKey {
        typealias Value = ClearDeletedUsersServiceType
    }

    var clearDeletedUsersService: ClearDeletedUsersServiceType {
        get {
            self.application.storage[ClearDeletedUsersServiceKey.self] ?? ClearDeletedUsersService()
        }
        nonmutating set {
            self.application.storage[ClearDeletedUsersServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ClearDeletedUsersServiceType: Sendable {
    /// Tries to remove remote users that failed to be fully removed.
    ///
    /// - Parameter context: The execution context providing access to services, settings, and the database.
    /// - Throws: An error if loading candidates fails.
    func clear(on context: ExecutionContext) async throws
}

/// A service for retrying remote user deletion between attempts (managed by job schedule).
final class ClearDeletedUsersService: ClearDeletedUsersServiceType {
    private let maxDeletionAttempts = 3

    func clear(on context: ExecutionContext) async throws {
        let weekAgo = Date.weekAgo
        let usersService = context.services.usersService

        let remoteUsers = try await User.query(on: context.db)
            .withDeleted()
            .filter(\.$isLocal == false)
            .all()
            .filter { user in
                guard let lastDeletionAttemptAt = user.lastDeletionAttemptAt,
                      lastDeletionAttemptAt <= weekAgo else {
                    return false
                }

                let deletionAttemptsCount = user.deletionAttemptsCount ?? 0
                return deletionAttemptsCount < maxDeletionAttempts
            }

        context.logger.info("[ClearDeletedUsersJob] Remote users to delete: \(remoteUsers.count).")

        for (index, remoteUser) in remoteUsers.enumerated() {
            do {
                context.logger.info("[ClearDeletedUsersJob] Deleting remote user (\(index + 1)/\(remoteUsers.count)): '\(remoteUser.stringId() ?? "")'.")
                try await usersService.delete(remoteUser: remoteUser, on: context)
            } catch {
                await context.logger.store("[ClearDeletedUsersJob] Delete remote user error.", error, on: context.application)
            }
        }
    }
}
