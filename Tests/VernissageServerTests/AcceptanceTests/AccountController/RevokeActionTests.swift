//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import Fluent

final class RevokeActionTests: CustomTestCase {
    
    func testOkStatusCodeShouldBeReturnedAfterRevokedRefreshTokenByAdministrator() async throws {
        // Arrange.
        let admin = try await User.create(userName: "annahights")
        try await admin.attach(role: Role.administrator)
        
        _ = try await User.create(userName: "martinhights")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "martinhights", password: "p@ssword")
        _ = try SharedApplication.application().sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "annahights", password: "p@ssword"),
            to: "/account/refresh-token/@martinhights",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }
    
    func testOkStatusCodeShouldBeReturnedAfterRevokedOwnRefreshToken() async throws {
        // Arrange.
        _ = try await User.create(userName: "vardyhights")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "vardyhights", password: "p@ssword")
        _ = try SharedApplication.application().sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "vardyhights", password: "p@ssword"),
            to: "/account/refresh-token/@vardyhights",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }
    
    func testNewRefreshTokenShouldNotBeReturnedWhenOldWereRevoked() async throws {
        // Arrange.
        let admin = try await User.create(userName: "victorhights")
        try await admin.attach(role: Role.administrator)
        
        _ = try await User.create(userName: "lidiahights")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "lidiahights", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application().getResponse(to: "/account/login",
                                                                             method: .POST,
                                                                             data: loginRequestDto,
                                                                             decodeTo: AccessTokenDto.self)

        // Act.
        _ = try SharedApplication.application().sendRequest(
            as: .user(userName: "victorhights", password: "p@ssword"),
            to: "/account/refresh-token/@lidiahights",
            method: .DELETE
        )
        
        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken)
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/refresh-token",
            method: .POST,
            data: refreshTokenDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "refreshTokenRevoked", "Error code should be equal 'refreshTokenRevoked'.")
    }
    
    func testNotFoundShouldBeReturnedWhenUserNotExists() async throws {
        // Arrange.
        let admin = try await User.create(userName: "rickyhights")
        try await admin.attach(role: Role.administrator)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "rickyhights", password: "p@ssword"),
            to: "/account/refresh-token/@notexists",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedStatusCodeShouldBeReturnedWhenUserIsNotAuthorized() throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/account/refresh-token/@user",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testForbiddenStatusCodeShouldBeReturnedWhenUserIsNotSuperUser() async throws {
        // Arrange.
        _ = try await User.create(userName: "michalehights")
        _ = try await User.create(userName: "burekhights")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "michalehights", password: "p@ssword"),
            to: "/account/refresh-token/@burekhights",
            method: .DELETE
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
}
