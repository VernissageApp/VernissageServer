@testable import App
import XCTest
import XCTVapor
import JWT

final class LoginActionTests: XCTestCase {

    func testUserWithCorrectCredentialsShouldBeSignedInByUsername() throws {

        // Arrange.
        _ = try User.create(userName: "nickfury")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "nickfury", password: "p@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let accessTokenDto = try response.content.decode(AccessTokenDto.self)
        XCTAssert(accessTokenDto.accessToken.count > 0, "Access token should be returned for correct credentials")
        XCTAssert(accessTokenDto.refreshToken.count > 0, "Refresh token should be returned for correct credentials")
    }

    func testUserWithCorrectCredentialsShouldBeSignedInByEmail() throws {

        // Arrange.
        _ = try User.create(userName: "rickfury")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "rickfury@testemail.com", password: "p@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let accessTokenDto = try response.content.decode(AccessTokenDto.self)
        XCTAssert(accessTokenDto.accessToken.count > 0, "Access token should be returned for correct credentials")
        XCTAssert(accessTokenDto.refreshToken.count > 0, "Refresh token should be returned for correct credentials")
    }

    func testAccessTokenShouldContainsBasicInformationAboutUser() throws {

        // Arrange.
        let user = try User.create(userName: "stevenfury")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "stevenfury@testemail.com", password: "p@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let accessTokenDto = try response.content.decode(AccessTokenDto.self)
        let authorizationPayload = try SharedApplication.application().jwt.signers.verify(accessTokenDto.accessToken, as: UserPayload.self)
        XCTAssertEqual(authorizationPayload.email, user.email, "Email should be included in JWT access token")
        XCTAssertEqual(authorizationPayload.id, user.id, "User id should be included in JWT access token")
        XCTAssertEqual(authorizationPayload.name, user.name, "Name should be included in JWT access token")
        XCTAssertEqual(authorizationPayload.userName, user.userName, "User name should be included in JWT access token")
        XCTAssertEqual(authorizationPayload.gravatarHash, user.gravatarHash, "Gravatar hash should be included in JWT access token")
    }

    func testAccessTokenShouldContainsInformationAboutUserRoles() throws {

        // Arrange.
        let user = try User.create(userName: "yokofury")
        try user.attach(role: "administrator")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "yokofury@testemail.com", password: "p@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let accessTokenDto = try response.content.decode(AccessTokenDto.self)
        let authorizationPayload = try SharedApplication.application().jwt.signers.verify(accessTokenDto.accessToken, as: UserPayload.self)
        XCTAssertEqual(authorizationPayload.roles[0], "administrator", "User roles should be included in JWT access token")
    }

    func testUserWithIncorrectPasswordShouldNotBeSignedIn() throws {

        // Arrange.
        _ = try User.create(userName: "martafury")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "martafury", password: "incorrect")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/login",
            method: .POST,
            data: loginRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "invalidLoginCredentials", "Error code should be equal 'invalidLoginCredentials'.")
    }

    func testUserWithNotConfirmedAccountShouldNotBeSignedIn() throws {

        // Arrange.
        _ = try User.create(userName: "josefury", emailWasConfirmed: false)
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "josefury", password: "p@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/login",
            method: .POST,
            data: loginRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "emailNotConfirmed", "Error code should be equal 'emailNotConfirmed'.")
    }

    func testUserWithBlockedAccountShouldNotBeSignedIn() throws {

        // Arrange.
        _ = try User.create(userName: "tomfury", isBlocked: true)
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "tomfury", password: "p@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/login",
            method: .POST,
            data: loginRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
    }
}

