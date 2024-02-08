//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class UsersUnfollowActionTests: CustomTestCase {
    
    func testUnfollowShouldFinishSuccessfullyForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictordera", generateKeys: true)
        let user2 = try await User.create(userName: "mariandera", generateKeys: true)
        
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        
        // Act.
        let relationship = try SharedApplication.application().getResponse(
            as: .user(userName: "wictordera", password: "p@ssword"),
            to: "/users/\(user2.userName)/unfollow",
            method: .POST,
            decodeTo: RelationshipDto.self
        )

        // Assert.
        XCTAssertFalse(relationship.following, "User 1 is following now User 2.")
    }
        
    func testUnfollowRequestsApproveShouldFailForUnauthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "hermandera", generateKeys: true)
        let user2 = try await User.create(userName: "robinedera", generateKeys: true)
        
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/users/\(user2.userName)/unfollow",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

