//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension ActivityPubClient {
    
    /// Sending follow request to remote server. Use shared inbox.
    func follow(_ actorTargetId: String, by actorSourceId: String, on inbox: URL, withId id: Int64) async throws {
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
            for: inbox,
            target: ActivityPub.Users.follow(actorSourceId, actorTargetId, privatePemKey, inbox.path, userAgent, host, id)
        )

        _ = try await downloadBody(request: request)
    }
    
    /// Sending unfollow request to remote server. Use shared inbox.
    func unfollow(_ actorTargetId: String, by actorSourceId: String, on inbox: URL, withId id: Int64) async throws {
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
            for: inbox,
            target: ActivityPub.Users.unfollow(actorSourceId, actorTargetId, privatePemKey, inbox.path, userAgent, host, id)
        )

        _ = try await downloadBody(request: request)
    }
    
    /// Sending follow accept request to remote server. Use user inbox.
    func accept(requesting actorSourceId: String, asked actorTargetId: String, on inbox: URL, withId id: Int64, orginalRequestId: String) async throws {
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
            for: inbox,
            target: ActivityPub.Users.accept(actorSourceId, actorTargetId, privatePemKey, inbox.path, userAgent, host, id, orginalRequestId)
        )

        _ = try await downloadBody(request: request)
    }
    
    /// Sendinng follow reject request to remote server. Use user inbox.
    func reject(requesting actorSourceId: String, asked actorTargetId: String, on inbox: URL, withId id: Int64, orginalRequestId: String) async throws {
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
            for: inbox,
            target: ActivityPub.Users.reject(actorSourceId, actorTargetId, privatePemKey, inbox.path, userAgent, host, id, orginalRequestId)
        )

        _ = try await downloadBody(request: request)
    }
    
    func delete(actorId: String, on inbox: URL) async throws {
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
            for: inbox,
            target: ActivityPub.Users.delete(actorId, privatePemKey, inbox.path, userAgent, host)
        )

        _ = try await downloadBody(request: request)
    }
}
