//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class FollowRequestsRejectActionTests: CustomTestCase {
    
    func testFollowRequestRejectShouldFinishSuccessfullyForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictormoro", generateKeys: true)
        let user2 = try await User.create(userName: "marianmoro", generateKeys: true)
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)

        // Act.
        let relationship = try SharedApplication.application().getResponse(
            as: .user(userName: "wictormoro", password: "p@ssword"),
            to: "/follow-requests/\(user2.stringId() ?? "")/reject",
            method: .POST,
            decodeTo: RelationshipDto.self
        )

        // Assert.
        XCTAssertFalse(relationship.followedBy, "User 2 is not following User 1.")
    }
        
    func testFollowRequestsRejectShouldFailForUnauthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "hermanmoro", generateKeys: true)
        let user2 = try await User.create(userName: "robinmoro", generateKeys: true)
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/follow-requests/\(user2.stringId() ?? "")/reject",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

