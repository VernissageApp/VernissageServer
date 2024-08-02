//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UsersRefreshActionTests: CustomTestCase {
    
    func testUserShouldBeRefreshedForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await User.create(userName: "johngiboq")
        try await user1.attach(role: Role.moderator)

        _ = try await User.create(userName: "markgiboq")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "johngiboq", password: "p@ssword"),
            to: "/users/@markgiboq/refresh",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }
    
    func testUserShouldNotBeRefreshedForRegularUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "fredgiboq")
        _ = try await User.create(userName: "tidegiboq")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "fredgiboq", password: "p@ssword"),
            to: "/users/@tidegiboq/refresh",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testRefreshShouldReturnNotFoundForNotExistingUser() async throws {
        
        // Arrange.
        let user = try await User.create(userName: "ewegiboq")
        try await user.attach(role: Role.moderator)
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "ewegiboq", password: "p@ssword"),
            to: "/users/@notexists/refresh",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testRefreshShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await User.create(userName: "rickgiboq")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            to: "/users/@rickderiq/refresh",
            method: .POST
        )
        
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
