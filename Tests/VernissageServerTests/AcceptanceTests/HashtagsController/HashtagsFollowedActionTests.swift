//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension ControllersTests {

    @Suite("Hashtags (GET /hashtags/followed)", .serialized, .tags(.hashtags))
    struct HashtagsFollowedActionTests {
        var application: Application!

        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `List of followed hashtags should be returned for authorized user`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "milenahashtags")
            _ = try await application.createUserFollowedHashtag(userId: user.requireID(), hashtag: "Street")
            _ = try await application.createUserFollowedHashtag(userId: user.requireID(), hashtag: "Nature")

            // Act.
            let followedHashtags = try await application.getResponse(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/hashtags/followed",
                method: .GET,
                decodeTo: [HashtagDto].self
            )

            // Assert.
            #expect(followedHashtags.count == 2, "Two followed hashtags should be returned.")
            #expect(followedHashtags.contains(where: { $0.name == "Street" }), "Street hashtag should be returned.")
            #expect(followedHashtags.contains(where: { $0.name == "Nature" }), "Nature hashtag should be returned.")
        }

        @Test
        func `Only followed hashtags of signed in user should be returned`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "julahashtags")
            let user2 = try await application.createUser(userName: "piotrhashtags")

            _ = try await application.createUserFollowedHashtag(userId: user1.requireID(), hashtag: "Portrait")
            _ = try await application.createUserFollowedHashtag(userId: user2.requireID(), hashtag: "Travel")

            // Act.
            let followedHashtags = try await application.getResponse(
                as: .user(userName: user1.userName, password: "p@ssword"),
                to: "/hashtags/followed",
                method: .GET,
                decodeTo: [HashtagDto].self
            )

            // Assert.
            #expect(followedHashtags.count == 1, "Only one hashtag should be returned for user1.")
            #expect(followedHashtags.first?.name == "Portrait", "Only user1 hashtag should be returned.")
        }

        @Test
        func `List of followed hashtags should not be returned for unauthorized user`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/hashtags/followed", method: .GET)

            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response status code should be unauthorized (401).")
        }
    }
}
