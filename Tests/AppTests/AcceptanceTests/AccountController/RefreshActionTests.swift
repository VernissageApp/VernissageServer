@testable import App
import XCTest
import XCTVapor

final class RefreshActionTests: XCTestCase {

    func testNewTokensShouldBeReturnedWhenOldRefreshTokenIsValid() throws {

        // Arrange.
        _ = try User.create(userName: "sandragreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "sandragreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)
        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken)

        // Act.
        let newRefreshTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/refresh", method: .POST, data: refreshTokenDto, decodeTo: AccessTokenDto.self)

        // Assert.
        XCTAssert(newRefreshTokenDto.refreshToken.count > 0, "New refresh token wasn't created.")
    }

    func testNewTokensShouldNotBeReturnedWhenOldRefreshTokenIsNotValid() throws {

        // Arrange.
        _ = try User.create(userName: "johngreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "johngreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)
        let refreshTokenDto = RefreshTokenDto(refreshToken: "\(accessTokenDto.refreshToken)00")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/refresh", method: .POST, body: refreshTokenDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testNewTokensShouldNotBeReturnedWhenOldRefreshTokenIsValidButUserIsBlocked() throws {

        // Arrange.
        let user = try User.create(userName: "timothygreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "timothygreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)

        user.isBlocked = true
        try user.save(on: SharedApplication.application().db).wait()
        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/refresh",
            method: .POST,
            data: refreshTokenDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
    }

    func testNewTokensShouldNotBeReturnedWhenOldRefreshTokenIsExpired() throws {

        // Arrange.
        _ = try User.create(userName: "wandagreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "wandagreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)

        let refreshToken = try RefreshToken.get(token: accessTokenDto.refreshToken)
        refreshToken.expiryDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        try refreshToken.save(on: SharedApplication.application().db).wait()

        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/refresh",
            method: .POST,
            data: refreshTokenDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "refreshTokenExpired", "Error code should be equal 'refreshTokenExpired'.")
    }

    func testNewTokensShouldNotBeReturnedWhenOldRefreshTokenIsRevoked() throws {

        // Arrange.
        _ = try User.create(userName: "alexagreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "alexagreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)

        let refreshToken = try RefreshToken.get(token: accessTokenDto.refreshToken)
        refreshToken.revoked = true
        try refreshToken.save(on: SharedApplication.application().db).wait()

        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/refresh",
            method: .POST,
            data: refreshTokenDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "refreshTokenRevoked", "Error code should be equal 'refreshTokenRevoked'.")
    }
}
