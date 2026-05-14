//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension ControllersTests {

    @Suite("Hashtags (POST /hashtags/:name/unfollow)", .serialized, .tags(.hashtags))
    struct HashtagsUnfollowActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Hashtag should be unfollowed for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "lenahashtags")
            _ = try await application.createUserFollowedHashtag(userId: user.requireID(), hashtag: "Street")

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/hashtags/street/unfollow",
                method: .POST
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response status code should be ok (200).")

            let followedHashtag = try await application.getUserFollowedHashtag(userId: user.requireID(), hashtagNormalized: "STREET")
            #expect(followedHashtag == nil, "Followed hashtag should be removed from database.")
        }

        @Test
        func `Unfollowing not existing hashtag should be idempotent`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "olghashtags")

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/hashtags/street/unfollow",
                method: .POST
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response status code should be ok (200).")

            let allFollowedHashtags = try await application.getUserFollowedHashtags(userId: user.requireID())
            #expect(allFollowedHashtags.isEmpty, "No hashtags should be stored for user.")
        }

        @Test
        func `Hashtag with encoded hash sign should be normalized when unfollowing`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "sashashtags")
            _ = try await application.createUserFollowedHashtag(userId: user.requireID(), hashtag: "Street")

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/hashtags/%23Street/unfollow",
                method: .POST
            )

            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response status code should be ok (200).")

            let followedHashtag = try await application.getUserFollowedHashtag(userId: user.requireID(), hashtagNormalized: "STREET")
            #expect(followedHashtag == nil, "Hashtag should be removed after normalization.")
        }

        @Test
        func `Hashtag should not be unfollowed for unauthorized user`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/hashtags/street/unfollow", method: .POST)

            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response status code should be unauthorized (401).")
        }
    }
}
