//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class UsersListActionTests: CustomTestCase {
    func testListOfUsersShouldBeReturnedForModeratorUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robinfux")
        try await user.attach(role: Role.moderator)
        
        // Act.
        let users = try SharedApplication.application().getResponse(
            as: .user(userName: "robinfux", password: "p@ssword"),
            to: "/users",
            method: .GET,
            decodeTo: PaginableResultDto<UserDto>.self
        )

        // Assert.
        XCTAssertNotNil(users, "Users should be returned.")
        XCTAssertTrue(users.data.count > 0, "Some users should be returned.")
    }
    
    func testListOfUsersShouldBeReturnedForAdministratorUser() async throws {

        // Arrange.
        let user1 = try await User.create(userName: "wikifux")
        try await user1.attach(role: Role.administrator)
        
        // Act.
        let users = try SharedApplication.application().getResponse(
            as: .user(userName: "wikifux", password: "p@ssword"),
            to: "/users",
            method: .GET,
            decodeTo: PaginableResultDto<UserDto>.self
        )

        // Assert.
        XCTAssertNotNil(users, "Users should be returned.")
        XCTAssertTrue(users.data.count > 0, "Some users should be returned.")
    }
    
    func testForbiddenShouldbeReturnedForRegularUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "trelfux")
        _ = try await User.create(userName: "mortenfux")
        
        // Act.
        let response = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "trelfux", password: "p@ssword"),
            to: "/users",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    func testListOfUsersShouldNotBeReturnedWhenUserIsNotAuthorized() async throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/users", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
