//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class RolesUpdateActionTests: CustomTestCase {

    func testCorrectRoleShouldBeUpdatedBySuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "brucelee")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "seller")
        let roleToUpdate = RoleDto(id: role.stringId(), code: "junior-seller", title: "Junior serller", description: "Junior seller")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "brucelee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            body: roleToUpdate
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        guard let updatedRole = try? await Role.get(code: "junior-seller") else {
            XCTAssert(true, "Role was not found")
            return
        }

        XCTAssertEqual(updatedRole.stringId(), roleToUpdate.id, "Role id should be correct.")
        XCTAssertEqual(updatedRole.title, roleToUpdate.title, "Role name should be correct.")
        XCTAssertEqual(updatedRole.code, roleToUpdate.code, "Role code should be correct.")
        XCTAssertEqual(updatedRole.description, roleToUpdate.description, "Role description should be correct.")
        XCTAssertEqual(updatedRole.isDefault, roleToUpdate.isDefault, "Role default should be correct.")
    }

    func testRoleShouldNotBeUpdatedIfUserIsNotSuperUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "georgelee")
        let role = try await Role.create(code: "senior-seller")
        let roleToUpdate = RoleDto(id: role.stringId(), code: "junior-seller", title: "Junior serller", description: "Junior seller")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "georgelee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            body: roleToUpdate
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    func testRoleShouldNotBeUpdatedIfRoleWithSameCodeExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "samlee")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "marketer")
        let roleToUpdate = RoleDto(id: role.stringId(), code: Role.administrator, title: "Administrator", description: "Administrator")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "samlee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            data: roleToUpdate
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "roleWithCodeExists", "Error code should be equal 'roleWithCodeExists'.")
    }

    func testRoleShouldNotBeUpdatedIfCodeIsTooLong() async throws {

        // Arrange.
        let user = try await User.create(userName: "wandalee")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "manager1")
        let roleToUpdate = RoleDto(id: role.stringId(), code: "123456789012345678901", title: "Senior manager", description: "Senior manager")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "wandalee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            data: roleToUpdate
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("code"), "is greater than maximum of 20 character(s)")
    }

    func testRoleShouldNotBeUpdatedIfNameIsTooLong() async throws {

        // Arrange.
        let user = try await User.create(userName: "monikalee")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "manager2")
        let roleToUpdate = RoleDto(id: role.stringId(),
                                   code: "senior-manager",
                                   title: "123456789012345678901234567890123456789012345678901",
                                   description: "Senior manager",
                                   isDefault: true)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "monikalee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            data: roleToUpdate
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("title"), "is greater than maximum of 50 character(s)")
    }

    func testRoleShouldNotBeUpdatedIfDescriptionIsTooLong() async throws {

        // Arrange.
        let user = try await User.create(userName: "annalee")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "manager3")
        let roleToUpdate = RoleDto(id: role.stringId(),
                                   code: "senior-manager",
                                   title: "Senior manager",
                                   description: "12345678901234567890123456789012345678901234567890" +
                                                "12345678901234567890123456789012345678901234567890" +
                                                "12345678901234567890123456789012345678901234567890" +
                                                "123456789012345678901234567890123456789012345678901",
                                   isDefault: true)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "annalee", password: "p@ssword"),
            to: "/roles/\(role.stringId() ?? "")",
            method: .PUT,
            data: roleToUpdate
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("description"), "is greater than maximum of 200 character(s) and is not null")
    }
}

