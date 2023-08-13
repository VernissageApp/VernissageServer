//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class UsersFollowersActionTests: CustomTestCase {
    
    func testFollowersListShouldBeReturned() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictortrogi")
        let user2 = try await User.create(userName: "mariantrogi")
        let user3 = try await User.create(userName: "ronaldtrogi")
        let user4 = try await User.create(userName: "annatrogi")
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user3.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user4.requireID(), targetId: user1.requireID(), approved: true)
        
        // Act.
        let followers = try SharedApplication.application().getResponse(
            to: "/users/\(user1.userName)/followers",
            method: .GET,
            decodeTo: [UserDto].self
        )
        
        // Assert.
        XCTAssertEqual(followers.count, 3, "All followers should be returned.")
    }
}
