@testable import App
import XCTest
import XCTVapor

final class UsersReadActionTests: XCTestCase {

    func testUserProfileShouldBeReturnedForExistingUser() throws {

        // Arrange.
        let user = try User.create(userName: "johnbush")

        // Act.
        let userDto = try SharedApplication.application().getResponse(
            as: .user(userName: "johnbush", password: "p@ssword"),
            to: "/users/@johnbush",
            decodeTo: UserDto.self
        )

        // Assert.
        XCTAssertEqual(userDto.id, user.id, "Property 'id' should be equal.")
        XCTAssertEqual(userDto.userName, user.userName, "Property 'userName' should be equal.")
        XCTAssertEqual(userDto.email, user.email, "Property 'email' should be equal.")
        XCTAssertEqual(userDto.name, user.name, "Property 'name' should be equal.")
        XCTAssertEqual(userDto.gravatarHash, user.gravatarHash, "Property 'gravatarHash' should be equal.")
        XCTAssertEqual(userDto.bio, user.bio, "Property 'bio' should be equal.")
        XCTAssertEqual(userDto.location, user.location, "Property 'location' should be equal.")
        XCTAssertEqual(userDto.website, user.website, "Property 'website' should be equal.")
        XCTAssertEqual(userDto.birthDate?.description, user.birthDate?.description, "Property 'birthDate' should be equal.")
    }

    func testUserProfileShouldNotBeReturnedForNotExistingUser() throws {

        // Act.
        let response = try SharedApplication.application().sendRequest(to: "/users/@not-exists", method: .GET)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testPublicProfileShouldNotContainsSensitiveInformation() throws {

        // Arrange.
        let user = try User.create(userName: "elizabush")

        // Act.
        let userDto = try SharedApplication.application()
            .getResponse(to: "/users/@elizabush", decodeTo: UserDto.self)

        // Assert.
        XCTAssertEqual(userDto.id, user.id, "Property 'id' should be equal.")
        XCTAssertEqual(userDto.userName, user.userName, "Property 'userName' should be equal.")
        XCTAssertEqual(userDto.name, user.name, "Property 'name' should be equal.")
        XCTAssertEqual(userDto.gravatarHash, user.gravatarHash, "Property 'gravatarHash' should be equal.")
        XCTAssertEqual(userDto.bio, user.bio, "Property 'bio' should be equal.")
        XCTAssertEqual(userDto.location, user.location, "Property 'location' should be equal.")
        XCTAssertEqual(userDto.website, user.website, "Property 'website' should be equal.")
        XCTAssert(userDto.email == nil, "Property 'email' must not be equal.")
        XCTAssert(userDto.birthDate == nil, "Property 'birthDate' must not be returned.")
    }
}
