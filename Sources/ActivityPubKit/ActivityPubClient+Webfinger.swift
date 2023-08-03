//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public extension ActivityPubClient {
    func webfinger(resource: String) async throws -> WebfingerDto {
        guard let baseURL else {
            throw NetworkError.unknownError
        }
        
        let request = try Self.request(
            for: baseURL,
            target: ActivityPub.WellKnown.webfinger(resource)
        )

        return try await downloadJson(WebfingerDto.self, request: request)
    }
}
