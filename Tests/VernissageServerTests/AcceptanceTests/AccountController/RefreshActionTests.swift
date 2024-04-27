//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class RefreshActionTests: CustomTestCase {
    
    func testNewTokensShouldBeReturnedWhenOldRefreshTokenIsValid() async throws {

        // Arrange.
        _ = try await User.create(userName: "sandragreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "sandragreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)
        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!)

        // Act.
        let newRefreshTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/refresh-token", method: .POST, data: refreshTokenDto, decodeTo: AccessTokenDto.self)

        // Assert.
        XCTAssertNotNil(newRefreshTokenDto.refreshToken, "Refresh token should not exist in response")
        XCTAssert(newRefreshTokenDto.refreshToken!.count > 0, "New refresh token wasn't created.")
    }
    
    func testNewTokensShouldBeReturnedWhenOldRefreshTokenIsValidWithUseCookies() async throws {

        // Arrange.
        _ = try await User.create(userName: "tobiszgreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "tobiszgreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)
        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!, useCookies: true)

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/refresh-token", method: .POST, body: refreshTokenDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let newRefreshTokenDto = try response.content.decode(AccessTokenDto.self)
        
        XCTAssertNil(newRefreshTokenDto.accessToken, "Access token should not exist in response")
        XCTAssertNil(newRefreshTokenDto.refreshToken, "Refresh token should not exist in response")
        XCTAssertNotNil(response.headers.setCookie?["access-token"], "Access token should exists in cookies")
        XCTAssertNotNil(response.headers.setCookie?["refresh-token"], "Access token should exists in cookies")
        XCTAssert(response.headers.setCookie!["access-token"]!.string.count > 0, "Access token should be returned for correct credentials")
        XCTAssert(response.headers.setCookie!["access-token"]!.string.count > 0, "Refresh token should be returned for correct credentials")
    }
    
    func testNewTokensShouldBeReturnedWhenOldRefreshTokenIsValidWithoutRegeneration() async throws {

        // Arrange.
        _ = try await User.create(userName: "trenixgreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "trenixgreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)
        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!, regenerateRefreshToken: false)

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/refresh-token", method: .POST, body: refreshTokenDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let newRefreshTokenDto = try response.content.decode(AccessTokenDto.self)
        
        XCTAssertNotNil(newRefreshTokenDto.accessToken, "Access token should not exist in response")
        XCTAssertNotNil(newRefreshTokenDto.refreshToken, "Refresh token should not exist in response")
        XCTAssertEqual(newRefreshTokenDto.refreshToken, refreshTokenDto.refreshToken, "Refresh token valus should noe be regenerated.")
    }

    func testNewTokensShouldNotBeReturnedWhenOldRefreshTokenIsNotValid() async throws {

        // Arrange.
        _ = try await User.create(userName: "johngreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "johngreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)
        let refreshTokenDto = RefreshTokenDto(refreshToken: "\(accessTokenDto.refreshToken ?? "")00")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/refresh-token", method: .POST, body: refreshTokenDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testNewTokensShouldNotBeReturnedWhenOldRefreshTokenIsValidButUserIsBlocked() async throws {

        // Arrange.
        let user = try await User.create(userName: "timothygreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "timothygreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)

        user.isBlocked = true
        try await user.save(on: SharedApplication.application().db)
        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/refresh-token",
            method: .POST,
            data: refreshTokenDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
    }

    func testNewTokensShouldNotBeReturnedWhenOldRefreshTokenIsExpired() async throws {

        // Arrange.
        _ = try await User.create(userName: "wandagreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "wandagreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)

        let refreshToken = try await RefreshToken.get(token: accessTokenDto.refreshToken!)
        refreshToken.expiryDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        try await refreshToken.save(on: SharedApplication.application().db)

        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/refresh-token",
            method: .POST,
            data: refreshTokenDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "refreshTokenExpired", "Error code should be equal 'refreshTokenExpired'.")
    }

    func testNewTokensShouldNotBeReturnedWhenOldRefreshTokenIsRevoked() async throws {

        // Arrange.
        _ = try await User.create(userName: "alexagreen")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "alexagreen", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)

        let refreshToken = try await RefreshToken.get(token: accessTokenDto.refreshToken!)
        refreshToken.revoked = true
        try await refreshToken.save(on: SharedApplication.application().db)

        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!)

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/refresh-token",
            method: .POST,
            data: refreshTokenDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidde (403).")
        XCTAssertEqual(errorResponse.error.code, "refreshTokenRevoked", "Error code should be equal 'refreshTokenRevoked'.")
    }
}
