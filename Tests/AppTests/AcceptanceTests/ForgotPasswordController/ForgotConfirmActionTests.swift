//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class ForgotConfirmActionTests: CustomTestCase {

    func testPasswordShouldBeChangeForCorrectToken() async throws {

        // Arrange.
        _ = try await User.create(userName: "annapink",
                                  forgotPasswordGuid: "ANNAPINKGUID",
                                  forgotPasswordDate: Date())
        
        let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "ANNAPINKGUID", password: "newP@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/forgot/confirm",
                         method: .POST,
                         body: confirmationRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")

        let newLoginRequestDto = LoginRequestDto(userNameOrEmail: "annapink", password: "newP@ssword")
        let newAccessTokenDto = try SharedApplication.application()
            .getResponse(to: "/account/login",
                         method: .POST,
                         data: newLoginRequestDto,
                         decodeTo: AccessTokenDto.self)

        XCTAssert(newAccessTokenDto.accessToken.count > 0, "User should be signed in with new password.")
    }

    func testPasswordShouldNotBeChangedForIncorrectToken() throws {

        // Arrange.
        let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "NOTEXISTS", password: "newP@ssword")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/forgot/confirm", method: .POST, body: confirmationRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testPasswordShouldNotBeChangedForBlockedUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "josephpink",
                                  isBlocked: true,
                                  forgotPasswordGuid: "JOSEPHPINKGUID",
                                  forgotPasswordDate: Date())
        let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "JOSEPHPINKGUID", password: "newP@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/forgot/confirm",
            method: .POST,
            data: confirmationRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
    }

    func testPasswordShouldNotBeChangeIfUserDidNotGenerateToken() async throws {

        // Arrange.
        _ = try await User.create(userName: "wladpink",
                                  forgotPasswordGuid: nil,
                                  forgotPasswordDate: nil)
        let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "WLADPINKGUID", password: "newP@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/forgot/confirm",
            method: .POST,
            data: confirmationRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testPasswordShouldNotBeChangedForOverdueToken() async throws {

        // Arrange.
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)
        _ = try await User.create(userName: "mariapink",
                                  forgotPasswordGuid: "MARIAPINKGUID",
                                  forgotPasswordDate: yesterday)
        let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "MARIAPINKGUID", password: "newP@ssword")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/forgot/confirm",
            method: .POST,
            data: confirmationRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "tokenExpired", "Error code should be equal 'tokenExpired'.")
    }

    func testPasswordShouldNotBeChangedWhenNewPasswordIsTooShort() async throws {

        // Arrange.
        _ = try await User.create(userName: "tatianapink",
                                  forgotPasswordGuid: "TATIANAGUID",
                                  forgotPasswordDate: Date())
        let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "TATIANAGUID", password: "1234567")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/forgot/confirm",
            method: .POST,
            data: confirmationRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'validationError'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("password"), "is less than minimum of 8 character(s) and is not a valid password")
    }

    func testPasswordShouldNotBeChangedWhenPasswordIsTooLong() async throws {

        // Arrange.
        _ = try await User.create(userName: "ewelinapink",
                                  forgotPasswordGuid: "EWELINAGUID",
                                  forgotPasswordDate: Date())
        let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "EWELINAGUID", password: "123456789012345678901234567890123")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/forgot/confirm",
            method: .POST,
            data: confirmationRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "validationError", "Error code should be equal 'userAccountIsBlocked'.")
        XCTAssertEqual(errorResponse.error.reason, "Validation errors occurs.")
        XCTAssertEqual(errorResponse.error.failures?.getFailure("password"), "is greater than maximum of 32 character(s) and is not a valid password")
    }
}
