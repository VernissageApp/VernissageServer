//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class RolesCreateActionTests: CustomTestCase {

    func testRoleShouldBeCreatedBySuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "laracroft")
        try user.attach(role: "administrator")
        let roleDto = RoleDto(code: "reviewer", title: "Reviewer", description: "Code reviewers")

        // Act.
        let createdRoleDto = try SharedApplication.application().getResponse(
            as: .user(userName: "laracroft", password: "p@ssword"),
            to: "/roles",
            method: .POST,
            data: roleDto,
            decodeTo: RoleDto.self
        )

        // Assert.
        XCTAssert(createdRoleDto.id != nil, "Role wasn't created.")
    }

    func testCreatedStatusCodeShouldBeReturnedAfterCreatingNewRole() throws {

        // Arrange.
        let user = try User.create(userName: "martincroft")
        try user.attach(role: "administrator")
        let roleDto = RoleDto(code: "tech-writer", title: "Technical writer", description: "Technical writer")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "martincroft", password: "p@ssword"),
            to: "/roles",
            method: .POST,
            body: roleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.created, "Response http status code should be created (201).")
    }

    func testHeaderLocationShouldBeReturnedAfterCreatingNewRole() throws {

        // Arrange.
        let user = try User.create(userName: "victorcroft")
        try user.attach(role: "administrator")
        let roleDto = RoleDto(code: "business-analyst", title: "Business analyst", description: "Business analyst")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "victorcroft", password: "p@ssword"),
            to: "/roles",
            method: .POST,
            body: roleDto
        )

        // Assert.
        let location = response.headers.first(name: .location)
        let role = try response.content.decode(RoleDto.self)
        XCTAssertEqual(location, "/roles/\(role.id ?? "")", "Location header should contains created role id.")
    }

    func testRoleShouldNotBeCreatedIfUserIsNotSuperUser() throws {

        // Arrange.
        _ = try User.create(userName: "robincroft")
        let roleDto = RoleDto(code: "developer", title: "Developer", description: "Developer")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "robincroft", password: "p@ssword"),
            to: "/roles",
            method: .POST,
            body: roleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    func testRoleShouldNotBeCreatedIfRoleWithSameCodeExists() throws {

        // Arrange.
        let user = try User.create(userName: "erikcroft")
        try user.attach(role: "administrator")
        let roleDto = RoleDto(code: "administrator", title: "Administrator", description: "Administrator")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "erikcroft", password: "p@ssword"),
            to: "/roles",
            method: .POST,
            data: roleDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "roleWithCodeExists", "Error code should be equal 'roleWithCodeExists'.")
    }

    func testRoleShouldNotBeCreatedIfCodeIsTooLong() throws {

        // Arrange.
        let user = try User.create(userName: "tedcroft")
        try user.attach(role: "administrator")
        let roleDto = RoleDto(code: "123456789012345678901", title: "name", description: "description")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "tedcroft", password: "p@ssword"),
            to: "/roles",
            method: .POST,
            data: roleDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("code"), "is greater than maximum of 20 character(s)")
    }

    func testRoleShouldNotBeCreatedIfNameIsTooLong() throws {

        // Arrange.
        let user = try User.create(userName: "romancroft")
        try user.attach(role: "administrator")
        let roleDto = RoleDto( code: "code", title: "123456789012345678901234567890123456789012345678901",description: "description")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "romancroft", password: "p@ssword"),
            to: "/roles",
            method: .POST,
            data: roleDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("title"), "is greater than maximum of 50 character(s)")
    }

    func testRoleShouldNotBeCreatedIfDescriptionIsTooLong() throws {

        // Arrange.
        let user = try User.create(userName: "samcroft")
        try user.attach(role: "administrator")
        let roleDto = RoleDto(code: "code",
                              title: "name",
                              description: "12345678901234567890123456789012345678901234567890" +
                                           "12345678901234567890123456789012345678901234567890" +
                                           "12345678901234567890123456789012345678901234567890" +
                                           "123456789012345678901234567890123456789012345678901",
                              hasSuperPrivileges: false,
                              isDefault: true)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "samcroft", password: "p@ssword"),
            to: "/roles",
            method: .POST,
            data: roleDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("description"), "is greater than maximum of 200 character(s) and is not null")
    }
}

