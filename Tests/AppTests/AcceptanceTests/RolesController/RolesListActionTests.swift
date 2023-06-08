//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class RolesListActionTests: CustomTestCase {

    func testListOfRolesShouldBeReturnedForSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "robinorange")
        try user.attach(role: "administrator")

        // Act.
        let roles = try SharedApplication.application().getResponse(
            as: .user(userName: "robinorange", password: "p@ssword"),
            to: "/roles",
            method: .GET,
            decodeTo: [RoleDto].self
        )

        // Assert.
        XCTAssert(roles.count > 0, "Role list was returned.")
    }

    func testListOfRolesShouldNotBeReturnedForNotSuperUser() throws {

        // Arrange.
        _ = try User.create(userName: "wictororange")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "wictororange", password: "p@ssword"),
            to: "/roles",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
    }
}
