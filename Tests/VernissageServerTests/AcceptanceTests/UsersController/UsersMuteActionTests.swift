//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UsersMuteActionTests: CustomTestCase {
    
    func testUserShouldBeMutedForAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "johnboby")
        _ = try await User.create(userName: "markboby")
        
        // Act.
        let relationshipDto = try SharedApplication.application().getResponse(
            as: .user(userName: "johnboby", password: "p@ssword"),
            to: "/users/@markboby/mute",
            method: .POST,
            data: UserMuteRequestDto(muteStatuses: true, muteReblogs: true, muteNotifications: true),
            decodeTo: RelationshipDto.self
        )
        
        // Assert.
        XCTAssertTrue(relationshipDto.mutedStatuses, "Statuses should be muted.")
        XCTAssertTrue(relationshipDto.mutedReblogs, "Reblogs should be muted.")
        XCTAssertTrue(relationshipDto.mutedNotifications, "Notifications should be muted.")
    }
    
    func testMuteShouldReturnNotFoundForNotExistingUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "eweboby")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "eweboby", password: "p@ssword"),
            to: "/users/@notexists/mute",
            method: .POST,
            data: UserMuteRequestDto(muteStatuses: true, muteReblogs: true, muteNotifications: true)
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testMuteShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "rickboby")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            to: "/users/@rickboby/mute",
            method: .POST,
            data: UserMuteRequestDto(muteStatuses: true, muteReblogs: true, muteNotifications: true)
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
