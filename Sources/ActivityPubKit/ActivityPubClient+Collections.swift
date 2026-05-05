//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public struct FeaturedCollectionPageDataDto {
    public let orderedItems: [String]
    public let first: String?
    public let next: String?

    public init(orderedItems: [String], first: String?, next: String?) {
        self.orderedItems = orderedItems
        self.first = first
        self.next = next
    }
}

public extension ActivityPubClient {
    /// Downloads a remote featured collection by its URL.
    /// - Parameters:
    ///   - url: The full URL of the remote collection.
    ///   - activityPubProfile: The ActivityPub actor id used to sign the request.
    /// - Returns: A deserialized `OrderedCollectionDto`.
    /// - Throws: An error when required client configuration is missing or the request fails.
    func featuredCollection(url: URL, activityPubProfile: String) async throws -> OrderedCollectionDto {
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
            for: url,
            target: ActivityPub.Collections.get(activityPubProfile, privatePemKey, self.signaturePath(for: url), userAgent, host)
        )

        return try await downloadJson(OrderedCollectionDto.self, request: request)
    }

    /// Downloads and normalizes ordered items metadata for featured collection endpoint.
    /// - Parameters:
    ///   - url: The full URL of the remote collection or page.
    ///   - activityPubProfile: The ActivityPub actor id used to sign the request.
    /// - Returns: Collection/page payload with `orderedItems` and pagination pointers.
    /// - Throws: An error when required client configuration is missing or the request/decoding fails.
    func featuredCollectionPageData(url: URL, activityPubProfile: String) async throws -> FeaturedCollectionPageDataDto {
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
            for: url,
            target: ActivityPub.Collections.get(activityPubProfile, privatePemKey, self.signaturePath(for: url), userAgent, host)
        )

        let (data, response) = try await urlSession.asyncData(for: request)
        guard (response as? HTTPURLResponse)?.status?.responseType == .success else {
            throw NetworkError.notSuccessResponse(response, data)
        }

        let decoder = JSONDecoder()
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {
            if type == "OrderedCollectionPage" {
                let page = try decoder.decode(OrderedCollectionPageDto.self, from: data)
                return FeaturedCollectionPageDataDto(orderedItems: page.orderedItems, first: nil, next: page.next)
            }

            if type == "OrderedCollection" {
                let collection = try decoder.decode(OrderedCollectionDto.self, from: data)
                return FeaturedCollectionPageDataDto(orderedItems: collection.orderedItems ?? [], first: collection.first, next: nil)
            }
        }

        if let collection = try? decoder.decode(OrderedCollectionDto.self, from: data) {
            return FeaturedCollectionPageDataDto(orderedItems: collection.orderedItems ?? [], first: collection.first, next: nil)
        }

        let page = try decoder.decode(OrderedCollectionPageDto.self, from: data)
        return FeaturedCollectionPageDataDto(orderedItems: page.orderedItems, first: nil, next: page.next)
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
