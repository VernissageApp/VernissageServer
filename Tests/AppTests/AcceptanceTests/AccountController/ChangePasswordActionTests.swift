@testable import App
import XCTest
import XCTVapor

final class ChangePasswordActionTests: XCTestCase {

    func testPasswordShouldBeChangedWhenAuthorizedUserChangePassword() throws {

        // Arrange.
        _ = try User.create(userName: "markuswhite")
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "newP@ssword")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "markuswhite", password: "p@ssword"),
            to: "/account/change-password",
            method: .POST, 
            body: changePasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let newLoginRequestDto = LoginRequestDto(userNameOrEmail: "markuswhite", password: "newP@ssword")
        let newAccessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: newLoginRequestDto, decodeTo: AccessTokenDto.self)
        XCTAssert(newAccessTokenDto.accessToken.count > 0, "User should be signed in with new password.")
    }

    func testPasswordShouldNotBeChangedWhenNotAuthorizedUserTriesToChangePassword() throws {

        // Arrange.
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "newP@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/change-password", method: .POST, body: changePasswordRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }

    func testPasswordShouldNotBeChangedWhenAuthorizedUserEntersWrongOldPassword() throws {

        // Arrange.
        _ = try User.create(userName: "annawhite")
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword-bad", newPassword: "newP@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "annawhite", password: "p@ssword"),
            to: "/account/change-password", 
            method: .POST,
            data: changePasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "invalidOldPassword", "Error code should be equal 'invalidOldPassword'.")
    }

    func testPasswordShouldNotBeChangedWhenUserAccountIsBlocked() throws {

        // Arrange.
        let user = try User.create(userName: "willwhite")
        let loginRequestDto = LoginRequestDto(userNameOrEmail: "willwhite", password: "p@ssword")
        let accessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)

        user.isBlocked = true
        try user.save(on: SharedApplication.application().db).wait()
        var headers: HTTPHeaders = HTTPHeaders()
        headers.add(name: .authorization, value: "Bearer \(accessTokenDto.accessToken)")
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "newP@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/change-password",
            method: .POST,
            headers: headers,
            data: changePasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
    }

    func testValidationErrorShouldBeReturnedWhenPasswordIsTooShort() throws {

        // Arrange.
        _ = try User.create(userName: "timwhite")
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "1234567")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "timwhite", password: "p@ssword"),
            to: "/account/change-password",
            method: .POST,
            data: changePasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("newPassword"), "is less than minimum of 8 character(s) and is not a valid password")
    }

    func testValidationErrorShouldBeReturnedWhenPasswordIsTooLong() throws {

        // Arrange.
        _ = try User.create(userName: "robinwhite")
        let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "123456789012345678901234567890123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "robinwhite", password: "p@ssword"),
            to: "/account/change-password",
            method: .POST,
            data: changePasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'userAccountIsBlocked'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("newPassword"), "is greater than maximum of 32 character(s) and is not a valid password")
    }
}
