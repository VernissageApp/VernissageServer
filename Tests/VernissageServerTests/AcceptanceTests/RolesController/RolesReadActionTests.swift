//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class RolesReadActionTests: CustomTestCase {

    func testRoleShouldBeReturnedForSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "robinyellow")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "senior-architect")

        // Act.
        let roleDto = try SharedApplication.application().getResponse(
            as: .user(userName: "robinyellow", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .GET,
            decodeTo: RoleDto.self
        )

        // Assert.
        XCTAssertEqual(roleDto.id, role.stringId(), "Role id should be correct.")
        XCTAssertEqual(roleDto.title, role.title, "Role name should be correct.")
        XCTAssertEqual(roleDto.code, role.code, "Role code should be correct.")
        XCTAssertEqual(roleDto.description, role.description, "Role description should be correct.")
        XCTAssertEqual(roleDto.isDefault, role.isDefault, "Role default should be correct.")
    }

    func testRoleShouldNotBeReturnedIfUserIsNotSuperUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "hulkyellow")
        let role = try await Role.create(code: "senior-developer")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "hulkyellow", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be bad request (400).")
    }

    func testCorrectStatusCodeShouldBeReturnedIdRoleNotExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "tedyellow")
        try await user.attach(role: Role.administrator)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "tedyellow", password: "p@ssword"),
            to: "/roles/757392",
            method: .GET
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
