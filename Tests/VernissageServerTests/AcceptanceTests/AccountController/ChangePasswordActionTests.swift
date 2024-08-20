//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor

final class ChangePasswordActionTests: CustomTestCase {
    
    func testPasswordShouldBeChangedWhenAuthorizedUserChangePassword() async throws {

        // Arrange.
        _ = try await User.create(userName: "markuswhite")
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "newP@ssword")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "markuswhite", password: "p@ssword"),
            to: "/account/password",
            method: .PUT,
            body: changePasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let newLoginRequestDto = LoginRequestDto(userNameOrEmail: "markuswhite", password: "newP@ssword")
        let newAccessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: newLoginRequestDto, decodeTo: AccessTokenDto.self)
        
        XCTAssertNotNil(newAccessTokenDto.accessToken, "Access token should not exist in response")
        XCTAssertNotNil(newAccessTokenDto.refreshToken, "Refresh token should not exist in response")
        XCTAssert(newAccessTokenDto.accessToken!.count > 0, "User should be signed in with new password.")
    }

    func testPasswordShouldNotBeChangedWhenNotAuthorizedUserTriesToChangePassword() throws {

        // Arrange.
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "newP@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/password", method: .PUT, body: changePasswordRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }

    func testPasswordShouldNotBeChangedWhenAuthorizedUserEntersWrongOldPassword() async throws {

        // Arrange.
        _ = try await User.create(userName: "annawhite")
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword-bad", newPassword: "newP@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "annawhite", password: "p@ssword"),
            to: "/account/password",
            method: .PUT,
            data: changePasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "invalidOldPassword", "Error code should be equal 'invalidOldPassword'.")
    }

    func testPasswordShouldNotBeChangedWhenUserAccountIsBlocked() async throws {

        // Arrange.
        let user = try await User.create(userName: "willwhite")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "willwhite", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)

        user.isBlocked = true
        try await user.save(on: SharedApplication.application().db)
        var headers: HTTPHeaders = HTTPHeaders()
        headers.add(name: .authorization, value: "Bearer \(accessTokenDto.accessToken!)")
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "newP@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/password",
            method: .PUT,
            headers: headers,
            data: changePasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
    }

    func testValidationErrorShouldBeReturnedWhenPasswordIsTooShort() async throws {

        // Arrange.
        _ = try await User.create(userName: "timwhite")
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "1234567")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "timwhite", password: "p@ssword"),
            to: "/account/password",
            method: .PUT,
            data: changePasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("newPassword"), "is less than minimum of 8 character(s) and is not a valid password")
    }

    func testValidationErrorShouldBeReturnedWhenPasswordIsTooLong() async throws {

        // Arrange.
        _ = try await User.create(userName: "robinwhite")
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "123456789012345678901234567890123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "robinwhite", password: "p@ssword"),
            to: "/account/password",
            method: .PUT,
            data: changePasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("newPassword"), "is greater than maximum of 32 character(s) and is not a valid password")
    }
}
