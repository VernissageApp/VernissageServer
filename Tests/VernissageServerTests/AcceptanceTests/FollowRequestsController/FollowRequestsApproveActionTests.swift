//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class FollowRequestsApproveActionTests: CustomTestCase {
    
    func testFollowRequestApproveShouldFinishSuccessfullyForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictorfubo", generateKeys: true)
        let user2 = try await User.create(userName: "marianfubo", generateKeys: true)
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)

        // Act.
        let relationship = try SharedApplication.application().getResponse(
            as: .user(userName: "wictorfubo", password: "p@ssword"),
            to: "/follow-requests/\(user2.stringId() ?? "")/approve",
            method: .POST,
            decodeTo: RelationshipDto.self
        )

        // Assert.
        XCTAssertTrue(relationship.followedBy, "User 2 is following now User 1.")
    }
        
    func testFollowRequestsApproveShouldFailForUnauthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "hermanfubo", generateKeys: true)
        let user2 = try await User.create(userName: "robinfubo", generateKeys: true)
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/follow-requests/\(user2.stringId() ?? "")/approve",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

