//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor
import Fluent

final class UsersDeleteActionTests: CustomTestCase {
    
    func testAccountShouldBeDeletedForAuthorizedUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "zibibonjek")
        
        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "zibibonjek", password: "p@ssword"),
            to: "/users/@zibibonjek",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try? await User.query(on: SharedApplication.application().db).filter(\.$userName == "zibibonjek").first()
        XCTAssert(userFromDb == nil, "User should be deleted.")
    }

    func testAccountShouldNotBeDeletedIfUserIsNotAuthorized() async throws {

        // Arrange.
        _ = try await User.create(userName: "victoriabonjek")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/users/@victoriabonjek", method: .DELETE)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }

    func testAccountShouldNotDeletedWhenUserTriesToDeleteNotHisAccount() async throws {

        // Arrange.
        _ = try await User.create(userName: "martabonjek")
        
        _ = try await User.create(userName: "kingabonjek",
                            email: "kingabonjek@testemail.com",
                            name: "Kinga Bonjek")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "martabonjek", password: "p@ssword"),
            to: "/users/@kingabonjek",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    func testForbiddenShouldBeReturnedIfAccountNotExists() async throws {

        // Arrange.
        _ = try await User.create(userName: "henrybonjek")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "henrybonjek", password: "p@ssword"),
            to: "/users/@notexists",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should forbidden (403).")
    }
}

