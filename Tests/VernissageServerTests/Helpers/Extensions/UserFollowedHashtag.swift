//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createUserFollowedHashtag(userId: Int64, hashtag: String) async throws -> UserFollowedHashtag {
        let id = await ApplicationManager.shared.generateId()
        let userFollowedHashtag = UserFollowedHashtag(id: id, userId: userId, hashtag: hashtag)
        _ = try await userFollowedHashtag.save(on: self.db)
        return userFollowedHashtag
    }

    func getUserFollowedHashtag(userId: Int64, hashtagNormalized: String) async throws -> UserFollowedHashtag? {
        return try await UserFollowedHashtag.query(on: self.db)
            .filter(\.$user.$id == userId)
            .filter(\.$hashtagNormalized == hashtagNormalized)
            .first()
    }

    func getUserFollowedHashtags(userId: Int64) async throws -> [UserFollowedHashtag] {
        return try await UserFollowedHashtag.query(on: self.db)
            .filter(\.$user.$id == userId)
            .all()
    }
}
