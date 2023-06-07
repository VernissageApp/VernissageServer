//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
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
    func exists(url: URL, on request: Request) async throws -> Bool
}

final class InstanceBlockedDomainsService: InstanceBlockedDomainsServiceType {
    public func exists(url: URL, on request: Request) async throws -> Bool {
        let count = try await InstanceBlockedDomain.query(on: request.db).count()
        return count > 0
    }
}
