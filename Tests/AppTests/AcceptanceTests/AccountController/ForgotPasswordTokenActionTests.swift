//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTest
import XCTVapor

final class TokenActionTests: CustomTestCase {

    func testForgotPasswordTokenShouldBeGeneratedForActiveUser() async throws {

        // Arrange.
        _ = try await User.create(userName: "johnred")
        let forgotPasswordRequestDto = ForgotPasswordRequestDto(email: "johnred@testemail.com", redirectBaseUrl: "http://localhost:4200")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/forgot/token", method: .POST, body: forgotPasswordRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }

    func testForgotPasswordTokenShouldNotBeGeneratedIfEmailNotExists() throws {

        // Arrange.
        let forgotPasswordRequestDto = ForgotPasswordRequestDto(email: "not-exists@testemail.com", redirectBaseUrl: "http://localhost:4200")

        // Act.
        let response = try SharedApplication.application()
            .sendRequest(to: "/account/forgot/token", method: .POST, body: forgotPasswordRequestDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testForgotPasswordTokenShouldNotBeGeneratedIfUserIsBlocked() async throws {

        // Arrange.
        _ = try await User.create(userName: "wikired", isBlocked: true)
        let forgotPasswordRequestDto = ForgotPasswordRequestDto(email: "wikired@testemail.com", redirectBaseUrl: "http://localhost:4200")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            to: "/account/forgot/token",
            method: .POST,
            data: forgotPasswordRequestDto
        )

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        XCTAssertEqual(errorResponse.error.code, "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
    }
}