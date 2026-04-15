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
    
    /// Sends a `Follow` activity to a remote actor.
    /// - Parameters:
    ///   - actorTargetId: The ActivityPub actor id being followed.
    ///   - actorSourceId: The ActivityPub actor id of the follower.
    ///   - inbox: The destination inbox URL, typically a shared inbox.
    ///   - id: The identifier used to build the outgoing follow activity id.
    /// - Throws: An error when required client configuration is missing or the request fails.
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
    
    /// Sends an undo for a previous `Follow` activity to a remote actor.
    /// - Parameters:
    ///   - actorTargetId: The ActivityPub actor id being unfollowed.
    ///   - actorSourceId: The ActivityPub actor id of the unfollowing actor.
    ///   - inbox: The destination inbox URL, typically a shared inbox.
    ///   - id: The identifier used to build the outgoing undo activity id.
    /// - Throws: An error when required client configuration is missing or the request fails.
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
    
    /// Sends an `Accept` activity for a previously received `Follow` request.
    /// - Parameters:
    ///   - actorSourceId: The ActivityPub actor id of the requesting actor.
    ///   - actorTargetId: The ActivityPub actor id accepting the follow request.
    ///   - inbox: The destination user inbox URL of the requester.
    ///   - id: The identifier used to build the outgoing accept activity id.
    ///   - orginalRequestId: The ActivityPub id of the original follow request.
    /// - Throws: An error when required client configuration is missing or the request fails.
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
    
    /// Sends a `Reject` activity for a previously received `Follow` request.
    /// - Parameters:
    ///   - actorSourceId: The ActivityPub actor id of the requesting actor.
    ///   - actorTargetId: The ActivityPub actor id rejecting the follow request.
    ///   - inbox: The destination user inbox URL of the requester.
    ///   - id: The identifier used to build the outgoing reject activity id.
    ///   - orginalRequestId: The ActivityPub id of the original follow request.
    /// - Throws: An error when required client configuration is missing or the request fails.
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
    
    /// Sends a `Delete` activity for a user actor to the target inbox.
    /// - Parameters:
    ///   - actorId: The ActivityPub actor id to delete.
    ///   - inbox: The destination inbox URL.
    /// - Throws: An error when required client configuration is missing or the request fails.
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
