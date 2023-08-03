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
    func person(id: String) async throws -> PersonDto {

        guard let profileUrl = URL(string: id) else {
            throw NetworkError.unknownError
        }
    
        let request = try Self.request(
            for: profileUrl,
            target: ActivityPub.Person.search
        )

        return try await downloadJson(PersonDto.self, request: request)
    }
}
