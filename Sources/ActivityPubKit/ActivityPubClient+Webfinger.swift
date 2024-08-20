//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension ActivityPubClient {
    func webfinger(url: URL) async throws -> WebfingerDto {
        let request = try Self.request(
            forFullUrl: url,
            target: ActivityPub.WellKnown.webfinger
        )

        return try await downloadJson(WebfingerDto.self, request: request)
    }
    
    func nodeinfo(baseUrl: URL) async throws -> NodeInfoDto {
        let request = try Self.request(
            for: baseUrl.appendingPathComponent(".well-known/nodeinfo"),
            target: ActivityPub.WellKnown.nodeinfo
        )

        return try await downloadJson(NodeInfoDto.self, request: request)
    }
    
    func hostMeta(baseUrl: URL) async throws -> String? {
        let request = try Self.request(
            for: baseUrl.appendingPathComponent(".well-known/host-meta"),
            target: ActivityPub.WellKnown.hostMeta
        )

        return try await downloadBody(request: request)
    }
}
