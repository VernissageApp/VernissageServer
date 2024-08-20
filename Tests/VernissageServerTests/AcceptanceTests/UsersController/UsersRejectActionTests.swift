//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UsersRejectActionTests: CustomTestCase {
    
    func testUserShouldBeRejectedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "johnrusq")
        try await user1.attach(role: Role.moderator)

        let user2 = try await User.create(userName: "markrusq", isApproved: false)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "johnrusq", password: "p@ssword"),
            to: "/users/@markrusq/reject",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userAfterRequest = try await User.get(id: user2.requireID(), withDeleted: true)
        XCTAssertNil(userAfterRequest, "User should be deleted completly from database.")
    }
    
    func testUserShouldNotBeRejectedForRegularUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "fredrusq")
        _ = try await User.create(userName: "tiderusq", isApproved: false)
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "fredrusq", password: "p@ssword"),
            to: "/users/@tiderusq/reject",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testRejectShouldReturnNotFoundForNotExistingUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "ewerusq")
        try await user.attach(role: Role.moderator)
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "ewerusq", password: "p@ssword"),
            to: "/users/@notexists/reject",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testRejectShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "rickrusq")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            to: "/users/@rickderiq/reject",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
