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
    /// Downloads a remote ActivityPub `Person` profile by actor id.
    /// - Parameters:
    ///   - id: The full ActivityPub actor URL to fetch.
    ///   - activityPubProfile: The ActivityPub actor id used to sign the request.
    /// - Returns: A deserialized `PersonDto` fetched from the remote server.
    /// - Throws: An error when the actor URL is invalid, required client configuration is missing, or the request fails.
    func person(id: String, activityPubProfile: String) async throws -> PersonDto {

        guard let profileUrl = URL(string: id) else {
            throw NetworkError.unknownError
        }
        
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
            for: profileUrl,
            target: ActivityPub.Person.search(activityPubProfile, privatePemKey, profileUrl.path, userAgent, host)
        )

        return try await downloadJson(PersonDto.self, request: request)
    }
}
