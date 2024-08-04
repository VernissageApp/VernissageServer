//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import JWT

final class LoginActionTests: CustomTestCase {
    
    func testUserWithCorrectCredentialsShouldBeSignedInByUsername() async throws {

        // Arrange.
        _ = try await User.create(userName: "nickfury")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "nickfury", password: "p@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let accessTokenDto = try response.content.decode(AccessTokenDto.self)
        XCTAssertNotNil(accessTokenDto.accessToken, "Access token should exist in response")
        XCTAssertNotNil(accessTokenDto.refreshToken, "Refresh token should exist in response")
        XCTAssert(accessTokenDto.accessToken!.count > 0, "Access token should be returned for correct credentials")
        XCTAssert(accessTokenDto.refreshToken!.count > 0, "Refresh token should be returned for correct credentials")
    }

    func testUserWithCorrectCredentialsShouldBeSignedInByEmail() async throws {

        // Arrange.
        _ = try await User.create(userName: "rickfury")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "rickfury@testemail.com", password: "p@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let accessTokenDto = try response.content.decode(AccessTokenDto.self)
        XCTAssertNotNil(accessTokenDto.accessToken, "Access token should exist in response")
        XCTAssertNotNil(accessTokenDto.refreshToken, "Refresh token should exist in response")
        XCTAssert(accessTokenDto.accessToken!.count > 0, "Access token should be returned for correct credentials")
        XCTAssert(accessTokenDto.refreshToken!.count > 0, "Refresh token should be returned for correct credentials")
    }
    
    func testUserWithCorrectCredentialsShouldBeSignedInByUsernameWithUseCookie() async throws {

        // Arrange.
        _ = try await User.create(userName: "teworfury")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "teworfury", password: "p@ssword", useCookies: true, trustMachine: false)

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let accessTokenDto = try response.content.decode(AccessTokenDto.self)
        XCTAssertNil(accessTokenDto.accessToken, "Access token should not exist in response")
        XCTAssertNil(accessTokenDto.refreshToken, "Refresh token should not exist in response")
        XCTAssertNotNil(response.headers.setCookie?[Constants.accessTokenName], "Access token should exists in cookies")
        XCTAssertNotNil(response.headers.setCookie?[Constants.refreshTokenName], "Access token should exists in cookies")
        XCTAssertNil(response.headers.setCookie?[Constants.isMachineTrustedName], "Is machine token should not exists in cookies")
        
        XCTAssert(response.headers.setCookie![Constants.accessTokenName]!.string.count > 0, "Access token should be returned for correct credentials")
        XCTAssert(response.headers.setCookie![Constants.refreshTokenName]!.string.count > 0, "Refresh token should be returned for correct credentials")
    }
    
    func testUserWithCorrectCredentialsShouldBeSignedInByUsernameWithUseCookieAndTrustedMachine() async throws {

        // Arrange.
        _ = try await User.create(userName: "vobofury")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "vobofury", password: "p@ssword", useCookies: true, trustMachine: true)

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        XCTAssertNotNil(response.headers.setCookie?[Constants.isMachineTrustedName], "Is machine trusted should exists in cookies")
        XCTAssert(response.headers.setCookie![Constants.isMachineTrustedName]!.string.count > 0, "Is machine trusted should be returned for correct credentials")
    }

    func testAccessTokenShouldContainsBasicInformationAboutUser() async throws {

        // Arrange.
        let user = try await User.create(userName: "stevenfury")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "stevenfury@testemail.com", password: "p@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let accessTokenDto = try response.content.decode(AccessTokenDto.self)
        
        XCTAssertNotNil(accessTokenDto.accessToken, "Access token should exist in response")
        let authorizationPayload = try SharedApplication.application().jwt.signers.verify(accessTokenDto.accessToken!, as: UserPayload.self)
        XCTAssertEqual(authorizationPayload.email, user.email, "Email should be included in JWT access token")
        XCTAssertEqual(authorizationPayload.id, user.stringId(), "User id should be included in JWT access token")
        XCTAssertEqual(authorizationPayload.name, user.name, "Name should be included in JWT access token")
        XCTAssertEqual(authorizationPayload.userName, user.userName, "User name should be included in JWT access token")
    }

    func testAccessTokenShouldContainsInformationAboutUserRoles() async throws {

        // Arrange.
        let user = try await User.create(userName: "yokofury")
        try await user.attach(role: Role.administrator)
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "yokofury@testemail.com", password: "p@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let accessTokenDto = try response.content.decode(AccessTokenDto.self)
        
        XCTAssertNotNil(accessTokenDto.accessToken, "Access token should exist in response")
        let authorizationPayload = try SharedApplication.application().jwt.signers.verify(accessTokenDto.accessToken!, as: UserPayload.self)
        XCTAssertEqual(authorizationPayload.roles[0], Role.administrator, "User roles should be included in JWT access token")
    }
    
    func testLastSignedDateShouldBeUpdatedAfterLogin() async throws {

        // Arrange.
        _ = try await User.create(userName: "tobyfury")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "tobyfury", password: "p@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let user = try await User.get(userName: "tobyfury")
        XCTAssertNotNil(user.lastLoginDate, "Last login date should be updated after login.")
    }

    func testUserWithIncorrectPasswordShouldNotBeSignedIn() async throws {

        // Arrange.
        _ = try await User.create(userName: "martafury")
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

    func testUserWithNotConfirmedAccountShouldBeSignedIn() async throws {

        // Arrange.
        _ = try await User.create(userName: "josefury", emailWasConfirmed: false)
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "josefury", password: "p@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/login",
                         method: .POST,
                         body: loginRequestDto)

        // Assert.
        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let accessTokenDto = try response.content.decode(AccessTokenDto.self)
        XCTAssertNotNil(accessTokenDto.accessToken, "Access token should exist in response")
        XCTAssertNotNil(accessTokenDto.refreshToken, "Refresh token should exist in response")
        XCTAssert(accessTokenDto.accessToken!.count > 0, "Access token should be returned for correct credentials")
        XCTAssert(accessTokenDto.refreshToken!.count > 0, "Refresh token should be returned for correct credentials")
    }

    func testUserWithBlockedAccountShouldNotBeSignedIn() async throws {

        // Arrange.
        _ = try await User.create(userName: "tomfury", isBlocked: true)
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "tomfury", password: "p@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/login",
            method: .POST,
            data: loginRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
    }
    
    func testUserWithNotApprovedAccountShouldNotBeSignedIn() async throws {

        // Arrange.
        _ = try await User.create(userName: "georgefury", isApproved: false)
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "georgefury", password: "p@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/login",
            method: .POST,
            data: loginRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "userAccountIsNotApproved", "Error code should be equal 'userAccountIsBlocked'.")
    }
}

