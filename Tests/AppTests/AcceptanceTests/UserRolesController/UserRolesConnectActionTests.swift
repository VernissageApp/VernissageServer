//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import Fluent

final class UserRolesConnectActionTests: XCTestCase {

    func testUserShouldBeConnectedToRoleForSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "nickford")
        try user.attach(role: "administrator")
        let role = try Role.create(code: "consultant")
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: role.id!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nickford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try User.query(on: SharedApplication.application().db).filter(\.$userName == "nickford").with(\.$roles).first().wait()
        XCTAssert(userFromDb!.roles.contains { $0.id == role.id! }, "Role should be attached to the user")
    }

    func testNothingShouldHappendWhenUserTriesToConnectAlreadyConnectedRole() throws {

        // Arrange.
        let user = try User.create(userName: "alanford")
        try user.attach(role: "administrator")
        let role = try Role.create(code: "policeman")
        try user.$roles.attach(role, on: SharedApplication.application().db).wait()
        
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: role.id!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "alanford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try User.query(on: SharedApplication.application().db).filter(\.$userName == "alanford").with(\.$roles).first().wait()
        XCTAssert(userFromDb!.roles.contains { $0.id == role.id! }, "Role should be attached to the user")
    }

    func testUserShouldNotBeConnectedToRoleIfUserIsNotSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "wandaford")
        let role = try Role.create(code: "senior-consultant")
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: role.id!)

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

    func testCorrectStatsCodeShouldBeReturnedIfUserNotExists() throws {

        // Arrange.
        let user = try User.create(userName: "henryford")
        try user.attach(role: "administrator")
        let role = try Role.create(code: "junior-consultant")
        let userRoleDto = UserRoleDto(userId: UUID(), roleId: role.id!)

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

    func testCorrectStatusCodeShouldBeReturnedIfRoleNotExists() throws {

        // Arrange.
        let user = try User.create(userName: "erikford")
        try user.attach(role: "administrator")
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: UUID())

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
