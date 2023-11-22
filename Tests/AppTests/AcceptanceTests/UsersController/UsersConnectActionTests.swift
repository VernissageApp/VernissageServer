//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import Fluent

final class UsersConnectActionTests: CustomTestCase {

    func testUserShouldBeConnectedToRoleForSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "nickford")
        try await user.attach(role: Role.administrator)
        let role = try await Role.create(code: "consultant")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nickford", password: "p@ssword"),
            to: "/users/\(user.userName)/connect/consultant",
            method: .POST
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

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "alanford", password: "p@ssword"),
            to: "/users/\(user.userName)/connect/policeman",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try await User.query(on: SharedApplication.application().db).filter(\.$userName == "alanford").with(\.$roles).first()
        XCTAssert(userFromDb!.roles.contains { $0.id == role.id! }, "Role should be attached to the user")
    }

    func testUserShouldNotBeConnectedToRoleIfUserIsNotSuperUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "wandaford")
        _ = try await Role.create(code: "senior-consultant")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "wandaford", password: "p@ssword"),
            to: "/users/\(user.userName)/connect/senior-consultant",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    func testNotFoundStatsCodeShouldBeReturnedIfUserNotExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "henryford")
        try await user.attach(role: Role.administrator)
        _ = try await Role.create(code: "junior-consultant")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "henryford", password: "p@ssword"),
            to: "/users/123322/connect/junior-consultant",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testCorrectStatusCodeShouldBeReturnedIfRoleNotExists() async throws {

        // Arrange.
        let user = try await User.create(userName: "erikford")
        try await user.attach(role: Role.administrator)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "erikford", password: "p@ssword"),
            to: "/users/\(user.userName)/connect/123",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
}
