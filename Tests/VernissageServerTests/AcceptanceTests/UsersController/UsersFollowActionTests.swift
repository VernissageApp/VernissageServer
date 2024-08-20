//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class UsersFollowActionTests: CustomTestCase {
    
    func testFollowShouldFinishSuccessfullyForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictorerst", generateKeys: true)
        let user2 = try await User.create(userName: "marianerst", generateKeys: true)
        
        // Act.
        let relationship = try SharedApplication.application().getResponse(
            as: .user(userName: "wictorerst", password: "p@ssword"),
            to: "/users/\(user2.userName)/follow",
            method: .POST,
            decodeTo: RelationshipDto.self
        )

        // Assert.
        XCTAssertTrue(relationship.following, "User 1 is following now User 2.")
        
        let notification = try await Notification.get(type: .follow, to: user2.requireID(), by: user1.requireID(), statusId: nil)
        XCTAssertNotNil(notification, "Notification should be added.")
    }
    
    func testFollowShouldBeRequestedForManualApproval() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "annaerst", generateKeys: true)
        let user2 = try await User.create(userName: "karinerst", manuallyApprovesFollowers: true, generateKeys: true)
        
        // Act.
        let relationship = try SharedApplication.application().getResponse(
            as: .user(userName: "annaerst", password: "p@ssword"),
            to: "/users/\(user2.userName)/follow",
            method: .POST,
            decodeTo: RelationshipDto.self
        )

        // Assert.
        XCTAssertFalse(relationship.following, "User 1 is following now User 2.")
        XCTAssertTrue(relationship.requested, "User 1 is requesting follow User 2.")
        
        let notification = try await Notification.get(type: .followRequest, to: user2.requireID(), by: user1.requireID(), statusId: nil)
        XCTAssertNotNil(notification, "Notification should be added.")
    }
        
    func testFollowRequestsApproveShouldFailForUnauthorizedUser() async throws {
        // Arrange.
        _ = try await User.create(userName: "hermanerst", generateKeys: true)
        let user2 = try await User.create(userName: "robinerst", generateKeys: true)
                
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/users/\(user2.userName)/follow",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

