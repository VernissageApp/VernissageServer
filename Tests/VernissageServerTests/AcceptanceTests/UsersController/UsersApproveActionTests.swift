//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UsersApproveActionTests: CustomTestCase {
    
    func testUserShouldBeApprovedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "johnderiq")
        try await user1.attach(role: Role.moderator)

        let user2 = try await User.create(userName: "markderiq", isApproved: false)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "johnderiq", password: "p@ssword"),
            to: "/users/@markderiq/approve",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userAfterRequest = try await User.get(id: user2.requireID())!
        XCTAssertTrue(userAfterRequest.isApproved, "User should be approved.")
    }
    
    func testUserShouldNotBeApprovedForRegularUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "fredderiq")
        _ = try await User.create(userName: "tidederiq", isApproved: false)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "fredderiq", password: "p@ssword"),
            to: "/users/@tidederiq/approve",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testApproveShouldReturnNotFoundForNotExistingUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "ewederiq")
        try await user.attach(role: Role.moderator)
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "ewederiq", password: "p@ssword"),
            to: "/users/@notexists/approve",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testApproveShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "rickderiq")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            to: "/users/@rickderiq/approve",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
