//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension Application.Services {
    struct InstanceBlockedDomainsServiceKey: StorageKey {
        typealias Value = InstanceBlockedDomainsServiceType
    }

    var instanceBlockedDomainsService: InstanceBlockedDomainsServiceType {
        get {
            self.application.storage[InstanceBlockedDomainsServiceKey.self] ?? InstanceBlockedDomainsService()
        }
        nonmutating set {
            self.application.storage[InstanceBlockedDomainsServiceKey.self] = newValue
        }
    }
}

protocol InstanceBlockedDomainsServiceType {
    func exists(on database: Database, url: URL) async throws -> Bool
}

final class InstanceBlockedDomainsService: InstanceBlockedDomainsServiceType {
    public func exists(on database: Database, url: URL) async throws -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }
        
        let count = try await InstanceBlockedDomain.query(on: database)
            .filter(\.$domain == host.lowercased())
            .count()

        return count > 0
    }
}
