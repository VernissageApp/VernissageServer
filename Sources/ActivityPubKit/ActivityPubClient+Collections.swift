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
    /// Downloads a remote featured collection by its URL.
    /// - Parameters:
    ///   - url: The full URL of the remote collection.
    ///   - activityPubProfile: The ActivityPub actor id used to sign the request.
    /// - Returns: A deserialized `OrderedCollectionDto` or `OrderedCollectionPageDto`.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func featuredCollection(url: URL, activityPubProfile: String) async throws -> AnyOrderedCollectionDto {
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
            forFullUrl: url,
            target: ActivityPub.Collections.get(activityPubProfile, privatePemKey, self.signaturePath(for: url), userAgent, host)
        )

        let (data, response) = try await urlSession.asyncData(for: request)
        let responseStatusCode = (response as? HTTPURLResponse)?.statusCode
        let responseType = responseStatusCode.flatMap { HTTPStatusCode(rawValue: $0)?.responseType }
        guard responseType == .success else {
            throw NetworkError.notSuccessResponse(response, data)
        }

        return try JSONDecoder().decode(AnyOrderedCollectionDto.self, from: data)
    }

    /// Sends an `Add` activity to add object into a featured collection.
    /// - Parameters:
    ///   - objectId: Object id to add.
    ///   - actorId: ActivityPub actor id used as sender.
    ///   - targetId: Collection id.
    ///   - inbox: The destination inbox URL.
    ///   - id: The identifier used to build the outgoing add activity id.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func addToFeatured(objectId: String, actorId: String, targetId: String, on inbox: URL, withId id: Int64) async throws {
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
            target: ActivityPub.Collections.add(objectId, actorId, targetId, privatePemKey, inbox.path, userAgent, host, id)
        )

        _ = try await downloadBody(request: request)
    }

    /// Sends a `Remove` activity to remove object from a featured collection.
    /// - Parameters:
    ///   - objectId: Object id to remove.
    ///   - actorId: ActivityPub actor id used as sender.
    ///   - targetId: Collection id.
    ///   - inbox: The destination inbox URL.
    ///   - id: The identifier used to build the outgoing remove activity id.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func removeFromFeatured(objectId: String, actorId: String, targetId: String, on inbox: URL, withId id: Int64) async throws {
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
            target: ActivityPub.Collections.remove(objectId, actorId, targetId, privatePemKey, inbox.path, userAgent, host, id)
        )

        _ = try await downloadBody(request: request)
    }

    private func signaturePath(for url: URL) -> String {
        if let query = url.query, query.isEmpty == false {
            return "\(url.path)?\(query)"
        }

        return url.path
    }
}
