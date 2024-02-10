//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import ActivityPubKit

final class RelationshipsListActionTests: CustomTestCase {
    
    func testRelatonshipsListShouldBeReturnedForAuthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictorrele")
        let user2 = try await User.create(userName: "marianrele")
        let user3 = try await User.create(userName: "annarele")
        let user4 = try await User.create(userName: "mariarele")
        
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user3.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user4.requireID(), approved: false)
        _ = try await Follow.create(sourceId: user4.requireID(), targetId: user1.requireID(), approved: true)

        // Act.
        let relationships = try SharedApplication.application().getResponse(
            as: .user(userName: "wictorrele", password: "p@ssword"),
            to: "/relationships?id[]=\(user2.requireID())&id[]=\(user3.requireID())&id[]=\(user4.requireID())",
            method: .GET,
            decodeTo: [RelationshipDto].self
        )

        // Assert.
        XCTAssertEqual(relationships.count, 3, "All relationships should be returned.")

        XCTAssertTrue(relationships.first(where: { $0.userId == user2.stringId() })?.following ?? false, "User 1 follows User 2.")
        XCTAssertFalse(relationships.first(where: { $0.userId == user2.stringId() })?.followedBy ?? false, "User 2 is not following User 1.")
        
        XCTAssertTrue(relationships.first(where: { $0.userId == user3.stringId() })?.following ?? false, "User 1 follows User 3.")
        XCTAssertFalse(relationships.first(where: { $0.userId == user3.stringId() })?.followedBy ?? false, "User 3 is not following User 1.")
        
        XCTAssertFalse(relationships.first(where: { $0.userId == user4.stringId() })?.following ?? false, "User 1 is not following yet User 4.")
        XCTAssertTrue(relationships.first(where: { $0.userId == user4.stringId() })?.requested ?? false, "User 1 requested following User 4.")
        XCTAssertTrue(relationships.first(where: { $0.userId == user4.stringId() })?.followedBy ?? false, "User 4 is following User 1.")
    }
    
    func testRelationshipsListShouldNotBeReturnedForUnauthorizedUser() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "hermanrele")
        let user2 = try await User.create(userName: "robinrele")
        
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/relationships?id[]=\(user2.requireID())",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}

