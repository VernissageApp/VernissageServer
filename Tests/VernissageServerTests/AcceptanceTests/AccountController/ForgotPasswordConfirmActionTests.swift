//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension AccountControllerTests {
    
    @Suite("POST /forgot/confirm", .serialized, .tags(.account))
    struct ForgotConfirmActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Password should be change for correct token")
        func passwordShouldBeChangeForCorrectToken() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "annapink",
                                                 forgotPasswordGuid: "ANNAPINKGUID",
                                                 forgotPasswordDate: Date())
            
            let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "ANNAPINKGUID", password: "newP@ssword")
            
            // Act.
            let response = try application.sendRequest(
                to: "/account/forgot/confirm",
                method: .POST,
                body: confirmationRequestDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let newLoginRequestDto = LoginRequestDto(userNameOrEmail: "annapink", password: "newP@ssword")
            let newAccessTokenDto = try application.getResponse(
                to: "/account/login",
                method: .POST,
                data: newLoginRequestDto,
                decodeTo: AccessTokenDto.self)
            
            #expect(newAccessTokenDto.accessToken != nil, "Access token should not exist in response")
            #expect(newAccessTokenDto.refreshToken != nil, "Refresh token should not exist in response")
            #expect(newAccessTokenDto.accessToken!.count > 0, "User should be signed in with new password.")
        }
        
        @Test("Password should not be changed for incorrect token")
        func passwordShouldNotBeChangedForIncorrectToken() throws {
            
            // Arrange.
            let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "NOTEXISTS", password: "newP@ssword")
            
            // Act.
            let response = try application.sendRequest(to: "/account/forgot/confirm", method: .POST, body: confirmationRequestDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Password should not be changed for blocked user")
        func passwordShouldNotBeChangedForBlockedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "josephpink",
                                                 isBlocked: true,
                                                 forgotPasswordGuid: "JOSEPHPINKGUID",
                                                 forgotPasswordDate: Date())
            
            let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "JOSEPHPINKGUID", password: "newP@ssword")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/account/forgot/confirm",
                method: .POST,
                data: confirmationRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
        }
        
        @Test("Password should not be change if user did not generate token")
        func passwordShouldNotBeChangeIfUserDidNotGenerateToken() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "wladpink",
                                                 forgotPasswordGuid: nil,
                                                 forgotPasswordDate: nil)
            let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "WLADPINKGUID", password: "newP@ssword")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/account/forgot/confirm",
                method: .POST,
                data: confirmationRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Password should not be changed for overdue token")
        func passwordShouldNotBeChangedForOverdueToken() async throws {
            
            // Arrange.
            let today = Date()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)
            _ = try await application.createUser(userName: "mariapink",
                                                 forgotPasswordGuid: "MARIAPINKGUID",
                                                 forgotPasswordDate: yesterday)
            let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "MARIAPINKGUID", password: "newP@ssword")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/account/forgot/confirm",
                method: .POST,
                data: confirmationRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "tokenExpired", "Error code should be equal 'tokenExpired'.")
        }
        
        @Test("Password should not be changed when new password is too short")
        func passwordShouldNotBeChangedWhenNewPasswordIsTooShort() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "tatianapink",
                                                 forgotPasswordGuid: "TATIANAGUID",
                                                 forgotPasswordDate: Date())
            let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "TATIANAGUID", password: "1234567")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/account/forgot/confirm",
                method: .POST,
                data: confirmationRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("password") == "is less than minimum of 8 character(s) and is not a valid password")
        }
        
        @Test("Password should not be changed when password is too long")
        func passwordShouldNotBeChangedWhenPasswordIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "ewelinapink",
                                                 forgotPasswordGuid: "EWELINAGUID",
                                                 forgotPasswordDate: Date())
            let confirmationRequestDto = ForgotPasswordConfirmationRequestDto(forgotPasswordGuid: "EWELINAGUID", password: "123456789012345678901234567890123")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/account/forgot/confirm",
                method: .POST,
                data: confirmationRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'userAccountIsBlocked'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("password") == "is greater than maximum of 32 character(s) and is not a valid password")
        }
    }
}
