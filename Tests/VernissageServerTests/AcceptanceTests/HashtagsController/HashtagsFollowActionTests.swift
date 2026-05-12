//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension ControllersTests {

    @Suite("Hashtags (POST /hashtags/:name/follow)", .serialized, .tags(.hashtags))
    struct HashtagsFollowActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Hashtag should be followed for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "edithashtags")

            // Act.
            let responseHashtag = try await application.getResponse(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/hashtags/street/follow",
                method: .POST,
                decodeTo: HashtagDto.self
            )

            // Assert.
            #expect(responseHashtag.name == "street", "Response should contain followed hashtag.")

            let followedHashtag = try await application.getUserFollowedHashtag(userId: user.requireID(), hashtagNormalized: "STREET")
            #expect(followedHashtag != nil, "Followed hashtag should be saved in database.")
            #expect(followedHashtag?.hashtag == "street", "Original hashtag should be saved.")
        }

        @Test
        func `Hashtag with encoded hash sign should be normalized when following`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "joannahashtags")

            // Act.
            let responseHashtag = try await application.getResponse(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/hashtags/%23Street/follow",
                method: .POST,
                decodeTo: HashtagDto.self
            )

            // Assert.
            #expect(responseHashtag.name == "Street", "Response should contain normalized followed hashtag.")

            let followedHashtag = try await application.getUserFollowedHashtag(userId: user.requireID(), hashtagNormalized: "STREET")
            #expect(followedHashtag?.hashtag == "Street", "Hash sign should be removed from hashtag.")
        }

        @Test
        func `Following existing hashtag should be idempotent`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "marinahashtags")
            _ = try await application.createUserFollowedHashtag(userId: user.requireID(), hashtag: "Street")

            // Act.
            let responseHashtag = try await application.getResponse(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/hashtags/street/follow",
                method: .POST,
                decodeTo: HashtagDto.self
            )

            // Assert.
            #expect(responseHashtag.name == "Street", "Existing hashtag should be returned in response.")

            let allFollowedHashtags = try await application.getUserFollowedHashtags(userId: user.requireID())
            #expect(allFollowedHashtags.count == 1, "Only one followed hashtag should exist in database.")
        }

        @Test
        func `Hashtag should not be followed for unauthorized user`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/hashtags/street/follow", method: .POST)

            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response status code should be unauthorized (401).")
        }
    }
}
