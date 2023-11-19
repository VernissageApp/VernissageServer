//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class UsersDisableActionTests: CustomTestCase {
    
    func testUserShouldBeDisabledForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "johngonter")
        try await user1.attach(role: Role.moderator)

        let user2 = try await User.create(userName: "markgonter", isBlocked: false)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "johngonter", password: "p@ssword"),
            to: "/users/@markgonter/disable",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userAfterRequest = try await User.get(id: user2.requireID())!
        XCTAssertTrue(userAfterRequest.isBlocked, "User should be blocked.")
    }
    
    func testUserShouldNotBeDisabledForRegularUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "fredgonter")
        _ = try await User.create(userName: "tidegonter", isBlocked: true)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "fredgonter", password: "p@ssword"),
            to: "/users/@tideervin/disable",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testDisableShouldReturnNotFoundForNotExistingUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "ewegonter")
        try await user.attach(role: Role.moderator)
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "ewegonter", password: "p@ssword"),
            to: "/users/@notexists/disable",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testDisableShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "rickgonter")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            to: "/users/@rickgonter/disable",
            method: .POST,
            data: UserMuteRequestDto(muteStatuses: true, muteReblogs: true, muteNotifications: true)
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
