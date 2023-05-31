@testable import App
import XCTest
import XCTVapor
import Fluent

final class RevokeActionTests: XCTestCase {
    
    func testOkStatusCodeShouldBeReturnedAfterRevokedRefreshToken() throws {
        // Arrange.
        let admin = try User.create(userName: "annahights")
        try admin.attach(role: "administrator")
        
        _ = try User.create(userName: "martinhights")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "martinhights", password: "p@ssword")
        _ = try SharedApplication.application().sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "annahights", password: "p@ssword"),
            to: "/account/revoke/@martinhights",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }
    
    func testNewRefreshTokenShouldNotBeReturnedWhenOldWereRevoked() throws {
        // Arrange.
        let admin = try User.create(userName: "victorhights")
        try admin.attach(role: "administrator")
        
        _ = try User.create(userName: "lidiahights")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "lidiahights", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application().getResponse(to: "/account/login",
                                                                             method: .POST,
                                                                             data: loginRequestDto,
                                                                             decodeTo: AccessTokenDto.self)

        // Act.
        _ = try SharedApplication.application().sendRequest(
            as: .user(userName: "victorhights", password: "p@ssword"),
            to: "/account/revoke/@lidiahights",
            method: .POST
        )
        
        let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken)
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/refresh",
            method: .POST,
            data: refreshTokenDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "refreshTokenRevoked", "Error code should be equal 'refreshTokenRevoked'.")
    }
    
    func testNotFoundShouldBeReturnedWhenUserNotExists() throws {
        // Arrange.
        let admin = try User.create(userName: "rickyhights")
        try admin.attach(role: "administrator")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "rickyhights", password: "p@ssword"),
            to: "/account/revoke/@notexists",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    func testUnauthorizedStatusCodeShouldBeReturnedWhenUserIsNotAuthorized() throws {
        // Act.
        let response = try SharedApplication.application().sendRequest(
            to: "/account/revoke/@user",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
    
    func testForbiddenStatusCodeShouldBeReturnedWhenUserIsNotSuperUser() throws {
        // Arrange.
        _ = try User.create(userName: "michalehights")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "michalehights", password: "p@ssword"),
            to: "/account/revoke/@user",
            method: .POST
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
}
