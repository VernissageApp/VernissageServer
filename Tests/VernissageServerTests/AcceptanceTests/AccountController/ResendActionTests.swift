//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTest
import XCTVapor
import Fluent

final class ResendActionTests: CustomTestCase {

    func testEmailShouldBeResendWhenEmailIsNotAlreadyConfirmed() async throws {

        // Arrange.
        _ = try await User.create(userName: "samanthabrix", emailWasConfirmed: false)
        let resendEmailConfirmationDto = ResendEmailConfirmationDto(redirectBaseUrl: "http://localhost")

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "samanthabrix", password: "p@ssword"),
            to: "/account/email/resend",
            method: .POST,
            body: resendEmailConfirmationDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
    }

    func testEmailShouldNotBeResendWhenEmailHasBeenAlreadyConfirmed() async throws {

        // Arrange.
        _ = try await User.create(userName: "erikbrix", emailWasConfirmed: true, emailConfirmationGuid: nil)
        let resendEmailConfirmationDto = ResendEmailConfirmationDto(redirectBaseUrl: "http://localhost")

        // Act.
        let errorResponse = try SharedApplication.application().getErrorResponse(
            as: .user(userName: "erikbrix", password: "p@ssword"),
            to: "/account/email/resend",
            method: .POST,
            data: resendEmailConfirmationDto)

        // Assert.
        XCTAssertEqual(errorResponse.status, HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        XCTAssertEqual(errorResponse.error.code, "emailIsAlreadyConfirmed", "Error code should be equal 'emailIsAlreadyConfirmed'.")
    }
    
    func testUnauthorizedStatusCodeShouldBeReturnedWhenUserIsNotAuthorized() throws {
        // Arrange.
        let resendEmailConfirmationDto = ResendEmailConfirmationDto(redirectBaseUrl: "http://localhost")

        // Act.        
        let response = try SharedApplication.application().sendRequest(
            to: "/account/email/resend",
            method: .POST,
            body: resendEmailConfirmationDto)

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
    }
}
