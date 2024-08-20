//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UsersUnmuteActionTests: CustomTestCase {
    
    func testUserShouldBeUnmutedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "johnvorx")
        let user2  = try await User.create(userName: "markvorx")
        _ = try await UserMute.create(userId: user1.requireID(), mutedUserId: user2.requireID(), muteStatuses: true, muteReblogs: true, muteNotifications: true)
        
        // Act.
        let relationshipDto = try SharedApplication.application().getResponse(
            as: .user(userName: "johnvorx", password: "p@ssword"),
            to: "/users/@markvorx/unmute",
            method: .POST,
            decodeTo: RelationshipDto.self
        )
        
        // Assert.
        XCTAssertFalse(relationshipDto.mutedStatuses, "Statuses should be muted.")
        XCTAssertFalse(relationshipDto.mutedReblogs, "Reblogs should be muted.")
        XCTAssertFalse(relationshipDto.mutedNotifications, "Notifications should be muted.")
    }
    
    func testUnmuteShouldReturnNotFoundForNotExistingUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "ewevorx")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "ewevorx", password: "p@ssword"),
            to: "/users/@notexists/unmute",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnmuteShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "rickvorx")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            to: "/users/@rickvorx/unmute",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
