//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
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
            decodeTo: LinkableResultDto<UserDto>.self
        )
        
        // Assert.
        XCTAssertEqual(following.data.count, 4, "All following users should be returned.")
    }
    
    func testFollowingFilteredByMinIdShouldBeReturned() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictorrquix")
        let user2 = try await User.create(userName: "marianrquix")
        let user3 = try await User.create(userName: "ronaldrquix")
        let user4 = try await User.create(userName: "annarquix")
        let user5 = try await User.create(userName: "rokrquix")
        
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        let secondFollow = try await Follow.create(sourceId: user1.requireID(), targetId: user3.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user4.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user5.requireID(), approved: true)
        
        // Act.
        let following = try SharedApplication.application().getResponse(
            to: "/users/\(user1.userName)/following?minId=\(secondFollow.stringId() ?? "")",
            method: .GET,
            decodeTo: LinkableResultDto<UserDto>.self
        )
        
        // Assert.
        XCTAssertEqual(following.data.count, 2, "All following users should be returned.")
        XCTAssertEqual(following.data[0].id, user5.stringId(), "First user should be returned.")
        XCTAssertEqual(following.data[1].id, user4.stringId(), "Second user should be returned.")
    }
    
    func testFollowingFilteredByMaxIdShouldBeReturned() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictortovin")
        let user2 = try await User.create(userName: "mariantovin")
        let user3 = try await User.create(userName: "ronaldtovin")
        let user4 = try await User.create(userName: "annatovin")
        let user5 = try await User.create(userName: "roktovin")
        
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user3.requireID(), approved: true)
        let thirdFollow = try await Follow.create(sourceId: user1.requireID(), targetId: user4.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user5.requireID(), approved: true)
        
        // Act.
        let following = try SharedApplication.application().getResponse(
            to: "/users/\(user1.userName)/following?maxId=\(thirdFollow.stringId() ?? "")",
            method: .GET,
            decodeTo: LinkableResultDto<UserDto>.self
        )
        
        // Assert.
        XCTAssertEqual(following.data.count, 2, "All following users should be returned.")
        XCTAssertEqual(following.data[0].id, user3.stringId(), "Previous user should be returned.")
        XCTAssertEqual(following.data[1].id, user2.stringId(), "Last user should be returned.")
    }
    
    func testFollowingListBasedOnLinableShouldBeReturned() async throws {
        // Arrange.
        let user1 = try await User.create(userName: "wictorgrovix")
        let user2 = try await User.create(userName: "mariangrovix")
        let user3 = try await User.create(userName: "ronaldgrovix")
        let user4 = try await User.create(userName: "annagrovix")
        let user5 = try await User.create(userName: "rokgrovix")
        
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
        _ = try await Follow.create(sourceId: user1.requireID(), targetId: user3.requireID(), approved: true)
        let thirdFollow = try await Follow.create(sourceId: user1.requireID(), targetId: user4.requireID(), approved: true)
        let fourthFollow = try await Follow.create(sourceId: user1.requireID(), targetId: user5.requireID(), approved: true)
        
        // Act.
        let following = try SharedApplication.application().getResponse(
            to: "/users/\(user1.userName)/following?limit=2",
            method: .GET,
            decodeTo: LinkableResultDto<UserDto>.self
        )
        
        // Assert.
        XCTAssertEqual(following.data.count, 2, "All following users should be returned.")
        XCTAssertEqual(following.maxId, thirdFollow.stringId(), "MaxId should be returned.")
        XCTAssertEqual(following.minId, fourthFollow.stringId(), "MinId should be returned.")
    }
}
