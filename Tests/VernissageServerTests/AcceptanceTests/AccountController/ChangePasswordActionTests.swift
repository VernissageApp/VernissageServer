//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("Account (PUT /account/password)", .serialized, .tags(.account))
    struct ChangePasswordActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Password should be changed when authorized user change password")
        func passwordShouldBeChangedWhenAuthorizedUserChangePassword() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "markuswhite")
            let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "newP@ssword")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "markuswhite", password: "p@ssword"),
                to: "/account/password",
                method: .PUT,
                body: changePasswordRequestDto
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let newLoginRequestDto = LoginRequestDto(userNameOrEmail: "markuswhite", password: "newP@ssword")
            let newAccessTokenDto = try application.getResponse(
                to: "/account/login",
                method: .POST,
                data: newLoginRequestDto,
                decodeTo: AccessTokenDto.self)
            
            #expect(newAccessTokenDto.accessToken != nil, "Access token should not exist in response")
            #expect(newAccessTokenDto.refreshToken != nil, "Refresh token should not exist in response")
            #expect(newAccessTokenDto.accessToken!.count > 0, "User should be signed in with new password.")
        }
        
        @Test("Password should not be changed when not authorized user tries to change password")
        func passwordShouldNotBeChangedWhenNotAuthorizedUserTriesToChangePassword() throws {
            
            // Arrange.
            let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "newP@ssword")
            
            // Act.
            let response = try application.sendRequest(
                to: "/account/password",
                method: .PUT,
                body: changePasswordRequestDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Password should not be changed when authorized user enters wrong old password")
        func passwordShouldNotBeChangedWhenAuthorizedUserEntersWrongOldPassword() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "annawhite")
            let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword-bad", newPassword: "newP@ssword")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "annawhite", password: "p@ssword"),
                to: "/account/password",
                method: .PUT,
                data: changePasswordRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "invalidOldPassword", "Error code should be equal 'invalidOldPassword'.")
        }
        
        @Test("Password should not be changed when user account is blocked")
        func passwordShouldNotBeChangedWhenUserAccountIsBlocked() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "willwhite")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "willwhite", password: "p@ssword")
            let accessTokenDto = try application.getResponse(
                to: "/account/login",
                method: .POST,
                data: loginRequestDto,
                decodeTo: AccessTokenDto.self)
            
            user.isBlocked = true
            try await user.save(on: application.db)
            var headers: HTTPHeaders = HTTPHeaders()
            headers.add(name: .authorization, value: "Bearer \(accessTokenDto.accessToken!)")
            let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "newP@ssword")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/account/password",
                method: .PUT,
                headers: headers,
                data: changePasswordRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
        }
        
        @Test("Validation error should be returned when password is too short")
        func validationErrorShouldBeReturnedWhenPasswordIsTooShort() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "timwhite")
            let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "1234567")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "timwhite", password: "p@ssword"),
                to: "/account/password",
                method: .PUT,
                data: changePasswordRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("newPassword") == "is less than minimum of 8 character(s) and is not a valid password")
        }
        
        @Test("Validation error should be returned when password is too long")
        func validationErrorShouldBeReturnedWhenPasswordIsTooLong() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "robinwhite")
            let changePasswordRequestDto = ChangePasswordRequestDto(currentPassword: "p@ssword", newPassword: "123456789012345678901234567890123")
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                as: .user(userName: "robinwhite", password: "p@ssword"),
                to: "/account/password",
                method: .PUT,
                data: changePasswordRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "validationError", "Error code should be equal 'validationError'.")
            #expect(errorResponse.error.reason == "Validation errors occurs.")
            #expect(errorResponse.error.failures?.getFailure("newPassword") == "is greater than maximum of 32 character(s) and is not a valid password")
        }
    }
}
