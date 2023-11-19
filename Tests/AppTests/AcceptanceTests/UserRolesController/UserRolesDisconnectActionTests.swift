//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import Fluent

final class UserRolesDisconnectActionTests: CustomTestCase {

    func testUserShouldBeDisconnectedWithRoleForSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "nickviolet")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "accountant")
        try await user.$roles.attach(role, on: SharedApplication.application().db)
        
        let userRoleDto = UserRoleDto(userId: user.stringId()!, roleCode: role.code)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nickviolet", password: "p@ssword"),
            to: "/user-roles/disconnect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try await User.query(on: SharedApplication.application().db).filter(\.$userName == "nickviolet").with(\.$roles).first()
        XCTAssert(!userFromDb!.roles.contains { $0.id == role.id! }, "Role should not be attached to the user")
    }

    func testNothingShouldHappanedWhenUserTriesDisconnectNotConnectedRole() async throws {

        // Arrange.
        let user = try await User.create(userName: "alanviolet")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "teacher")
        let userRoleDto = UserRoleDto(userId: user.stringId()!, roleCode: role.code)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "alanviolet", password: "p@ssword"),
            to: "/user-roles/disconnect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try await User.query(on: SharedApplication.application().db).filter(\.$userName == "alanviolet").with(\.$roles).first()
        XCTAssert(!userFromDb!.roles.contains { $0.id == role.id! }, "Role should not be attached to the user")
    }

    func testUserShouldNotBeDisconnectedWithRoleIfUserIsNotSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "fennyviolet")
        let role = try await Role.create(code: "junior-specialist")
        try await user.$roles.attach(role, on: SharedApplication.application().db)
        let userRoleDto = UserRoleDto(userId: user.stringId()!, roleCode: role.code)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "fennyviolet", password: "p@ssword"),
            to: "/user-roles/disconnect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    func testCorrectStatsCodeShouldBeReturnedIfUserNotExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "timviolet")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "senior-driver")
        try await user.$roles.attach(role, on: SharedApplication.application().db)
        let userRoleDto = UserRoleDto(userId: "4533425", roleCode: role.code)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "timviolet", password: "p@ssword"),
            to: "/user-roles/disconnect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testCorrectStatusCodeShouldBeReturnedIfRoleNotExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "danviolet")
        try await user.attach(role: Role.administrator)
        let userRoleDto = UserRoleDto(userId: "843533", roleCode: "123")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "danviolet", password: "p@ssword"),
            to: "/user-roles/disconnect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
