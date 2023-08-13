//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class FollowRequestsListActionTests: CustomTestCase {
    
    func testFollowRequestsListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictorgorgo")
        let user2 = try await User.create(userName: "mariangorgo")
        let user3 = try await User.create(userName: "annagorgo")
        let user4 = try await User.create(userName: "mariagorgo")
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
        _ = try await Follow.create(sourceId: user3.requireID(), targetId: user1.requireID(), approved: false)
        _ = try await Follow.create(sourceId: user4.requireID(), targetId: user1.requireID(), approved: false)

        // Act.
        let followRequests = try SharedApplication.application().getResponse(
            as: .user(userName: "wictorgorgo", password: "p@ssword"),
            to: "/follow-requests?page=0&size=10",
            method: .GET,
            decodeTo: [RelationshipDto].self
        )

        // Assert.
        XCTAssertEqual(followRequests.count, 3, "All follow requests should be returned.")
        
        XCTAssertFalse(followRequests.first(where: { $0.userId == user2.stringId() })?.following ?? false, "User 2 is not following yet User 1.")
        XCTAssertTrue(followRequests.first(where: { $0.userId == user2.stringId() })?.requestedBy ?? false, "User 2 requested following User 1.")
        
        XCTAssertFalse(followRequests.first(where: { $0.userId == user3.stringId() })?.following ?? false, "User 3 is not following yet User 1.")
        XCTAssertTrue(followRequests.first(where: { $0.userId == user3.stringId() })?.requestedBy ?? false, "User 3 requested following User 1.")
        
        XCTAssertFalse(followRequests.first(where: { $0.userId == user4.stringId() })?.following ?? false, "User 4 is not following yet User 1.")
        XCTAssertTrue(followRequests.first(where: { $0.userId == user4.stringId() })?.requestedBy ?? false, "User 4 requested following User 1.")
    }
    
    func testFirstPageOfFollowRequestsShouldBeReturnedWhenSizeHasBeenSpecified() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "rikigorgo")
        let user2 = try await User.create(userName: "yokogorgo")
        let user3 = try await User.create(userName: "ulagorgo")
        let user4 = try await User.create(userName: "olagorgo")
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
        _ = try await Follow.create(sourceId: user3.requireID(), targetId: user1.requireID(), approved: false)
        _ = try await Follow.create(sourceId: user4.requireID(), targetId: user1.requireID(), approved: false)

        // Act.
        let followRequests = try SharedApplication.application().getResponse(
            as: .user(userName: "rikigorgo", password: "p@ssword"),
            to: "/follow-requests?page=0&size=2",
            method: .GET,
            decodeTo: [RelationshipDto].self
        )

        // Assert.
        XCTAssertEqual(followRequests.count, 2, "All follow requests should be returned.")
    }
    
    func testFollowRequestsShouldNotBeReturnedForUnauthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "hermangorgo")
        let user2 = try await User.create(userName: "robingorgo")
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/follow-requests?page=0&size=2",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

