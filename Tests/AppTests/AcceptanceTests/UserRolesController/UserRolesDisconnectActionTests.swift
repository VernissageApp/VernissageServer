@testable import App
import XCTest
import XCTVapor
import Fluent

final class UserRolesDisconnectActionTests: XCTestCase {

    func testUserShouldBeDisconnectedWithRoleForSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "nickviolet")
        try user.attach(role: "administrator")
        let role = try Role.create(code: "accountant")
        try user.$roles.attach(role, on: SharedApplication.application().db).wait()
        
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: role.id!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nickviolet", password: "p@ssword"),
            to: "/user-roles/disconnect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try User.query(on: SharedApplication.application().db).filter(\.$userName == "nickviolet").with(\.$roles).first().wait()
        XCTAssert(!userFromDb!.roles.contains { $0.id == role.id! }, "Role should not be attached to the user")
    }

    func testNothingShouldHappanedWhenUserTriesDisconnectNotConnectedRole() throws {

        // Arrange.
        let user = try User.create(userName: "alanviolet")
        try user.attach(role: "administrator")
        let role = try Role.create(code: "teacher")
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: role.id!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "alanviolet", password: "p@ssword"),
            to: "/user-roles/disconnect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try User.query(on: SharedApplication.application().db).filter(\.$userName == "alanviolet").with(\.$roles).first().wait()
        XCTAssert(!userFromDb!.roles.contains { $0.id == role.id! }, "Role should not be attached to the user")
    }

    func testUserShouldNotBeDisconnectedWithRoleIfUserIsNotSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "fennyviolet")
        let role = try Role.create(code: "junior-specialist")
        try user.$roles.attach(role, on: SharedApplication.application().db).wait()
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: role.id!)

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

    func testCorrectStatsCodeShouldBeReturnedIfUserNotExists() throws {

        // Arrange.
        let user = try User.create(userName: "timviolet")
        try user.attach(role: "administrator")
        let role = try Role.create(code: "senior-driver")
        try user.$roles.attach(role, on: SharedApplication.application().db).wait()
        let userRoleDto = UserRoleDto(userId: UUID(), roleId: role.id!)

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

    func testCorrectStatusCodeShouldBeReturnedIfRoleNotExists() throws {

        // Arrange.
        let user = try User.create(userName: "danviolet")
        try user.attach(role: "administrator")
        let userRoleDto = UserRoleDto(userId: UUID(), roleId: UUID())

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
