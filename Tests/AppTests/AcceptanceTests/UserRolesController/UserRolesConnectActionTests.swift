//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import Fluent

final class UserRolesConnectActionTests: CustomTestCase {

    func testUserShouldBeConnectedToRoleForSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "nickford")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "consultant")
        let userRoleDto = UserRoleDto(userId: user.stringId()!, roleId: role.stringId()!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nickford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try await User.query(on: SharedApplication.application().db).filter(\.$userName == "nickford").with(\.$roles).first()
        XCTAssert(userFromDb!.roles.contains { $0.id == role.id! }, "Role should be attached to the user")
    }

    func testNothingShouldHappendWhenUserTriesToConnectAlreadyConnectedRole() async throws {

        // Arrange.
        let user = try await User.create(userName: "alanford")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "policeman")
        try await user.$roles.attach(role, on: SharedApplication.application().db)
        
        let userRoleDto = UserRoleDto(userId: user.stringId()!, roleId: role.stringId()!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "alanford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try await User.query(on: SharedApplication.application().db).filter(\.$userName == "alanford").with(\.$roles).first()
        XCTAssert(userFromDb!.roles.contains { $0.id == role.id! }, "Role should be attached to the user")
    }

    func testUserShouldNotBeConnectedToRoleIfUserIsNotSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "wandaford")
        let role = try await Role.create(code: "senior-consultant")
        let userRoleDto = UserRoleDto(userId: user.stringId()!, roleId: role.stringId()!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "wandaford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    func testCorrectStatsCodeShouldBeReturnedIfUserNotExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "henryford")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "junior-consultant")
        let userRoleDto = UserRoleDto(userId: "4234312", roleId: role.stringId()!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "henryford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testCorrectStatusCodeShouldBeReturnedIfRoleNotExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "erikford")
        try await user.attach(role: Role.administrator)
        let userRoleDto = UserRoleDto(userId: user.stringId()!, roleId: "123")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "erikford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
