//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UsersEnableActionTests: CustomTestCase {
    
    func testUserShouldBeEnabledForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "johnervin")
        try await user1.attach(role: Role.moderator)

        let user2 = try await User.create(userName: "markervin", isBlocked: true)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "johnervin", password: "p@ssword"),
            to: "/users/@markervin/enable",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userAfterRequest = try await User.get(id: user2.requireID())!
        XCTAssertFalse(userAfterRequest.isBlocked, "User should be ubblocked.")
    }
    
    func testUserShouldNotBeEnabledForRegularUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "fredervin")
        _ = try await User.create(userName: "tideervin", isBlocked: true)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "fredervin", password: "p@ssword"),
            to: "/users/@tideervin/enable",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testEnableShouldReturnNotFoundForNotExistingUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "eweervin")
        try await user.attach(role: Role.moderator)
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "eweervin", password: "p@ssword"),
            to: "/users/@notexists/enable",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testEnableShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "rickervin")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            to: "/users/@rickervin/enable",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
