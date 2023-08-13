//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import ActivityPubKit

final class UsersFollowingActionTests: CustomTestCase {
    
    func testFollowingListShouldBeReturned() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictortroga")
        let user2 = try await User.create(userName: "mariantroga")
        let user3 = try await User.create(userName: "ronaldtroga")
        let user4 = try await User.create(userName: "annatroga")
        let user5 = try await User.create(userName: "roktroga")
        
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user3.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user4.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user5.requireID(), approved: true)
        
        // Act.
        let following = try SharedApplication.application().getResponse(
            to: "/users/\(user1.userName)/following",
            method: .GET,
            decodeTo: [UserDto].self
        )
        
        // Assert.
        XCTAssertEqual(following.count, 4, "All following users should be returned.")
    }
}
