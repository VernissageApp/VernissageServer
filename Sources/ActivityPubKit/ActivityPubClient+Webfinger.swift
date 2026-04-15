//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension ActivityPubClient {
    /// Downloads the WebFinger document from a full `.well-known/webfinger` URL.
    /// - Parameters:
    ///   - url: The full WebFinger endpoint URL with query parameters.
    /// - Returns: A deserialized `WebfingerDto` fetched from the remote server.
    /// - Throws: An error when request creation fails or the response cannot be decoded.
    func webfinger(url: URL) async throws -> WebfingerDto {
        let request = try Self.request(
            forFullUrl: url,
            target: ActivityPub.WellKnown.webfinger
        )

        return try await downloadJson(WebfingerDto.self, request: request)
    }
    
    /// Downloads the NodeInfo discovery document from `/.well-known/nodeinfo`.
    /// - Parameters:
    ///   - baseUrl: The base URL of the remote instance.
    /// - Returns: A deserialized `NodeInfoDto` fetched from the remote server.
    /// - Throws: An error when request creation fails or the response cannot be decoded.
    func nodeinfo(baseUrl: URL) async throws -> NodeInfoDto {
        let request = try Self.request(
            for: baseUrl.appendingPathComponent(".well-known/nodeinfo"),
            target: ActivityPub.WellKnown.nodeinfo
        )

        return try await downloadJson(NodeInfoDto.self, request: request)
    }
    
    /// Downloads the host-meta document from `/.well-known/host-meta`.
    /// - Parameters:
    ///   - baseUrl: The base URL of the remote instance.
    /// - Returns: The raw host-meta document content, or `nil` when the response has no body.
    /// - Throws: An error when request creation fails or the response cannot be downloaded.
    func hostMeta(baseUrl: URL) async throws -> String? {
        let request = try Self.request(
            for: baseUrl.appendingPathComponent(".well-known/host-meta"),
            target: ActivityPub.WellKnown.hostMeta
        )

        return try await downloadBody(request: request)
    }
}
