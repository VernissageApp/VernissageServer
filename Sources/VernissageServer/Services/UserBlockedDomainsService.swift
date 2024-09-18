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
    func exists(on database: Database, url: URL) async throws -> Bool
}

/// A service for managing domains blocked by the user.
final class UserBlockedDomainsService: UserBlockedDomainsServiceType {
    public func exists(on database: Database, url: URL) async throws -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }
        
        let count = try await UserBlockedDomain.query(on: database)
            .filter(\.$domain == host.lowercased())
            .count()

        return count > 0
    }
}
