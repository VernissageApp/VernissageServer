//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class UsersReadActionTests: CustomTestCase {

    func testUserProfileShouldBeReturnedForExistingUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "johnbush")

        // Act.
        let userDto = try SharedApplication.application().getResponse(
            as: .user(userName: "johnbush", password: "p@ssword"),
            to: "/users/@johnbush",
            decodeTo: UserDto.self
        )

        // Assert.
        XCTAssertEqual(userDto.id, user.stringId(), "Property 'id' should be equal.")
        XCTAssertEqual(userDto.account, user.account, "Property 'userName' should be equal.")
        XCTAssertEqual(userDto.userName, user.userName, "Property 'userName' should be equal.")
        XCTAssertEqual(userDto.email, user.email, "Property 'email' should be equal.")
        XCTAssertEqual(userDto.name, user.name, "Property 'name' should be equal.")
        XCTAssertEqual(userDto.bio, user.bio, "Property 'bio' should be equal.")
    }

    func testUserProfileShouldNotBeReturnedForNotExistingUser() throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/users/@not-exists", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testPublicProfileShouldNotContainsSensitiveInformation() async throws {

        // Arrange.
        let user = try await User.create(userName: "elizabush")

        // Act.
        let userDto = try SharedApplication.application()
            .getResponse(to: "/users/@elizabush", decodeTo: UserDto.self)

        // Assert.
        XCTAssertEqual(userDto.id, user.stringId(), "Property 'id' should be equal.")
        XCTAssertEqual(userDto.userName, user.userName, "Property 'userName' should be equal.")
        XCTAssertEqual(userDto.name, user.name, "Property 'name' should be equal.")
        XCTAssertEqual(userDto.bio, user.bio, "Property 'bio' should be equal.")
        XCTAssert(userDto.email == nil, "Property 'email' must not be equal.")
    }
}
