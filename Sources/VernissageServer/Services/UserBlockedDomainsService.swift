//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension Application.Services {
    struct UserBlockedDomainsServiceKey: StorageKey {
        typealias Value = UserBlockedDomainsServiceType
    }

    var userBlockedDomainsService: UserBlockedDomainsServiceType {
        get {
            self.application.storage[UserBlockedDomainsServiceKey.self] ?? UserBlockedDomainsService()
        }
        nonmutating set {
            self.application.storage[UserBlockedDomainsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol UserBlockedDomainsServiceType: Sendable {
    /// Checks whether the given domain (host from URL) is blocked by the user.
    /// - Parameters:
    ///   - url: The URL whose domain is checked against the block list.
    ///   - database: Database to perform the query on.
    /// - Returns: True if the domain is blocked by the user.
    /// - Throws: Database errors.
    func exists(url: URL, on database: Database) async throws -> Bool
}

/// A service for managing domains blocked by the user.
final class UserBlockedDomainsService: UserBlockedDomainsServiceType {
    public func exists(url: URL, on database: Database) async throws -> Bool {
        guard let host = url.host else {
            return false
        }

        let normalizedHost = host.lowercased()
        let count = try await UserBlockedDomain.query(on: database)
            .filter(\.$domain == normalizedHost)
            .count()

        return count > 0
    }
}

