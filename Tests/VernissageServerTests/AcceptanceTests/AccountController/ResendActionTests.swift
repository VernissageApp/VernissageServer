//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("Account (POST /account/email/resend)", .serialized, .tags(.account))
    struct ResendActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Email should be resend when email is not already confirmed")
        func emailShouldBeResendWhenEmailIsNotAlreadyConfirmed() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "samanthabrix", emailWasConfirmed: false)
            let resendEmailConfirmationDto = ResendEmailConfirmationDto(redirectBaseUrl: "http://localhost")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "samanthabrix", password: "p@ssword"),
                to: "/account/email/resend",
                method: .POST,
                body: resendEmailConfirmationDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        }
        
        @Test("Email should not be resend when email has been already confirmed")
        func emailShouldNotBeResendWhenEmailHasBeenAlreadyConfirmed() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "erikbrix", emailWasConfirmed: true, emailConfirmationGuid: nil)
            let resendEmailConfirmationDto = ResendEmailConfirmationDto(redirectBaseUrl: "http://localhost")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "erikbrix", password: "p@ssword"),
                to: "/account/email/resend",
                method: .POST,
                data: resendEmailConfirmationDto)
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "emailIsAlreadyConfirmed", "Error code should be equal 'emailIsAlreadyConfirmed'.")
        }
        
        @Test("Unauthorized status code should be returned when user is not authorized")
        func unauthorizedStatusCodeShouldBeReturnedWhenUserIsNotAuthorized() throws {
            // Arrange.
            let resendEmailConfirmationDto = ResendEmailConfirmationDto(redirectBaseUrl: "http://localhost")
            
            // Act.
            let response = try application.sendRequest(
                to: "/account/email/resend",
                method: .POST,
                body: resendEmailConfirmationDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
