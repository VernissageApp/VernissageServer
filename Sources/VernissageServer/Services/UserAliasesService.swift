//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

extension Application.Services {
    struct UserAliasesServiceKey: StorageKey {
        typealias Value = UserAliasesServiceType
    }

    var userAliasesService: UserAliasesServiceType {
        get {
            self.application.storage[UserAliasesServiceKey.self] ?? UserAliasesService()
        }
        nonmutating set {
            self.application.storage[UserAliasesServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol UserAliasesServiceType: Sendable {
    /// Resolves ActivityPub profile URL for a given alias.
    ///
    /// The method first attempts to resolve alias as a local account (`isLocal == true`)
    /// and falls back to remote resolution through WebFinger.
    ///
    /// - Parameters:
    ///   - alias: Alias provided by user (e.g. `user` or `user@domain.tld`).
    ///   - context: Execution context with database and services access.
    /// - Returns: ActivityPub profile URL when alias can be resolved; otherwise `nil`.
    /// - Throws: Database errors during local user lookup.
    func resolveActivityPubProfile(for alias: String, on context: ExecutionContext) async throws -> String?
}

final class UserAliasesService: UserAliasesServiceType {
    func resolveActivityPubProfile(for alias: String, on context: ExecutionContext) async throws -> String? {
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAlias = trimmedAlias.deletingPrefix("@")
        guard normalizedAlias.isEmpty == false else {
            return nil
        }

        let usersService = context.services.usersService
        if let userFromDb = try await usersService.get(userName: normalizedAlias, on: context.db),
           userFromDb.isLocal {
            return userFromDb.activityPubProfile
        }

        let searchService = context.services.searchService
        return await searchService.getRemoteActivityPubProfile(userName: normalizedAlias, on: context)
    }
}
