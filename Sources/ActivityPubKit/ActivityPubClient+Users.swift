//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension ActivityPubClient {
    func follow(_ actorTargetId: String, by actorSourceId: String, on sharedInbox: URL, withId id: Int64) async throws {
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }
        
        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }
        
        let request = try Self.request(
            for: sharedInbox,
            target: ActivityPub.Users.follow(actorSourceId, actorTargetId, privatePemKey, sharedInbox.path, userAgent, host, id)
        )

        _ = try await downloadBody(request: request)
    }
    
    func unfollow(_ actorTargetId: String, by actorSourceId: String, on sharedInbox: URL, withId id: Int64) async throws {
        guard let privatePemKey else {
            throw GenericError.missingPrivateKey
        }
        
        guard let userAgent = self.userAgent else {
            throw GenericError.missingUserAgent
        }

        guard let host = self.host else {
            throw GenericError.missingHost
        }
        
        let request = try Self.request(
            for: sharedInbox,
            target: ActivityPub.Users.unfollow(actorSourceId, actorTargetId, privatePemKey, sharedInbox.path, userAgent, host, id)
        )

        _ = try await downloadBody(request: request)
    }
}
