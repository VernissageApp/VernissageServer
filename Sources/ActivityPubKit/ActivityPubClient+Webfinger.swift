//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension ActivityPubClient {
    func webfinger(baseUrl: URL, resource: String) async throws -> WebfingerDto {        
        let request = try Self.request(
            for: baseUrl.appendingPathComponent(".well-known/webfinger"),
            target: ActivityPub.WellKnown.webfinger(resource)
        )

        return try await downloadJson(WebfingerDto.self, request: request)
    }
    
    func nodeinfo(baseUrl: URL, resource: String) async throws -> NodeInfoDto {
        let request = try Self.request(
            for: baseUrl.appendingPathComponent(".well-known/nodeinfo"),
            target: ActivityPub.WellKnown.nodeinfo
        )

        return try await downloadJson(NodeInfoDto.self, request: request)
    }
    
    func hostMeta(baseUrl: URL, resource: String) async throws -> String? {
        let request = try Self.request(
            for: baseUrl.appendingPathComponent(".well-known/host-meta"),
            target: ActivityPub.WellKnown.hostMeta
        )

        return try await downloadBody(request: request)
    }
}
