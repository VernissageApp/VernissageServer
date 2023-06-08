//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class RolesDeleteActionTests: CustomTestCase {

    func testRoleShouldBeDeletedIfRoleExistsAndUserIsSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "alinahood")
        try user.attach(role: "administrator")
        let roleToDelete = try Role.create(code: "tester-analyst")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "alinahood", password: "p@ssword"),
            to: "/roles/\(roleToDelete.stringId() ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let role = try? Role.get(code: "tester-analyst")
        XCTAssert(role == nil, "Role should be deleted.")
    }

    func testRoleShouldNotBeDeletedIfRoleExistsButUserIsNotSuperUser() throws {

        // Arrange.
        _ = try User.create(userName: "robinhood")
        let roleToDelete = try Role.create(code: "technican")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "robinhood", password: "p@ssword"),
            to: "/roles/\(roleToDelete.stringId() ?? "")",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
    }

    func testCorrectStatusCodeShouldBeReturnedIfRoleNotExists() throws {

        // Arrange.
        let user = try User.create(userName: "wikihood")
        try user.attach(role: "administrator")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "wikihood", password: "p@ssword"),
            to: "/roles/7668",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
