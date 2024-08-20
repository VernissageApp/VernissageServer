//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
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
            decodeTo: LinkableResultDto<UserDto>.self
        )
        
        // Assert.
        XCTAssertEqual(followers.data.count, 3, "All followers should be returned.")
    }
    
    func testFollowingFilteredByMinIdShouldBeReturned() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictorqowix")
        let user2 = try await User.create(userName: "marianqowix")
        let user3 = try await User.create(userName: "ronaldqowix")
        let user4 = try await User.create(userName: "annaqowix")
        let user5 = try await User.create(userName: "rokqowix")
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
        let secondFollow = try await Follow.create(sourceId: user3.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user4.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user5.requireID(), targetId: user1.requireID(), approved: true)
        
        // Act.
        let followers = try SharedApplication.application().getResponse(
            to: "/users/\(user1.userName)/followers?minId=\(secondFollow.stringId() ?? "")",
            method: .GET,
            decodeTo: LinkableResultDto<UserDto>.self
        )
        
        // Assert.
        XCTAssertEqual(followers.data.count, 2, "All followers users should be returned.")
        XCTAssertEqual(followers.data[0].id, user5.stringId(), "First user should be returned.")
        XCTAssertEqual(followers.data[1].id, user4.stringId(), "Second user should be returned.")
    }
    
    func testFollowingFilteredByMaxIdShouldBeReturned() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictorforqin")
        let user2 = try await User.create(userName: "marianforqin")
        let user3 = try await User.create(userName: "ronaldforqin")
        let user4 = try await User.create(userName: "annaforqin")
        let user5 = try await User.create(userName: "rokforqin")
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user3.requireID(), targetId: user1.requireID(), approved: true)
        let thirdFollow = try await Follow.create(sourceId: user4.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user5.requireID(), targetId: user1.requireID(), approved: true)
        
        // Act.
        let followers = try SharedApplication.application().getResponse(
            to: "/users/\(user1.userName)/followers?maxId=\(thirdFollow.stringId() ?? "")",
            method: .GET,
            decodeTo: LinkableResultDto<UserDto>.self
        )
        
        // Assert.
        XCTAssertEqual(followers.data.count, 2, "All followers users should be returned.")
        XCTAssertEqual(followers.data[0].id, user3.stringId(), "Previous user should be returned.")
        XCTAssertEqual(followers.data[1].id, user2.stringId(), "Last user should be returned.")
    }
    
    func testFollowingListBasedOnLinableShouldBeReturned() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictorbohen")
        let user2 = try await User.create(userName: "marianbohen")
        let user3 = try await User.create(userName: "ronaldbohen")
        let user4 = try await User.create(userName: "annagbohen")
        let user5 = try await User.create(userName: "rokbohen")
        
        _ = try await Follow.create(sourceId: user2.requireID(), targetId: user1.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user3.requireID(), targetId: user1.requireID(), approved: true)
        let thirdFollow = try await Follow.create(sourceId: user4.requireID(), targetId: user1.requireID(), approved: true)
        let fourthFollow = try await Follow.create(sourceId: user5.requireID(), targetId: user1.requireID(), approved: true)
        
        // Act.
        let followers = try SharedApplication.application().getResponse(
            to: "/users/\(user1.userName)/followers?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<UserDto>.self
        )
        
        // Assert.
        XCTAssertEqual(followers.data.count, 2, "All followers users should be returned.")
        XCTAssertEqual(followers.maxId, thirdFollow.stringId(), "MaxId should be returned.")
        XCTAssertEqual(followers.minId, fourthFollow.stringId(), "MinId should be returned.")
    }
}
