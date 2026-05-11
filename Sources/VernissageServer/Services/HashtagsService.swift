//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct HashtagsServiceKey: StorageKey {
        typealias Value = HashtagsServiceType
    }

    var hashtagsService: HashtagsServiceType {
        get {
            self.application.storage[HashtagsServiceKey.self] ?? HashtagsService()
        }
        nonmutating set {
            self.application.storage[HashtagsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol HashtagsServiceType: Sendable {
    /// Clears hashtag value by removing `#` characters and trimming surrounding white spaces.
    ///
    /// - Parameter hashtag: Raw hashtag value.
    /// - Returns: Cleaned hashtag value.
    func clear(hashtag: String) -> String
    
    /// Returns followed hashtag for selected user and normalized hashtag value.
    ///
    /// - Parameters:
    ///   - userId: User identifier.
    ///   - hashtagNormalized: Hashtag normalized value.
    ///   - database: Database instance.
    /// - Returns: Followed hashtag object or `nil` when not found.
    /// - Throws: An error when database query fails.
    func getUserFollowedHashtag(for userId: Int64,
                                hashtagNormalized: String,
                                on database: Database) async throws -> UserFollowedHashtag?
}

/// A service with helper operations related to hashtags.
final class HashtagsService: HashtagsServiceType {
    func clear(hashtag: String) -> String {
        hashtag
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func getUserFollowedHashtag(for userId: Int64,
                                hashtagNormalized: String,
                                on database: Database) async throws -> UserFollowedHashtag? {
        return try await UserFollowedHashtag.query(on: database)
            .filter(\.$user.$id == userId)
            .filter(\.$hashtagNormalized == hashtagNormalized)
            .first()
    }
}
