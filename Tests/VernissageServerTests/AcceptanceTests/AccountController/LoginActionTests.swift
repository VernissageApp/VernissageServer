//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("Account (POST /account/login)", .serialized, .tags(.account))
    struct LoginActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User with correct credentials should be signed in by username")
        func userWithCorrectCredentialsShouldBeSignedInByUsername() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "nickfury")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "nickfury", password: "p@ssword")
            
            // Act.
            let response = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let accessTokenDto = try response.content.decode(AccessTokenDto.self)
            #expect(accessTokenDto.accessToken != nil, "Access token should exist in response")
            #expect(accessTokenDto.refreshToken != nil, "Refresh token should exist in response")
            #expect(accessTokenDto.accessToken!.count > 0, "Access token should be returned for correct credentials")
            #expect(accessTokenDto.refreshToken!.count > 0, "Refresh token should be returned for correct credentials")
        }
        
        @Test("User with correct credentials should be signed in by email")
        func userWithCorrectCredentialsShouldBeSignedInByEmail() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickfury")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "rickfury@testemail.com", password: "p@ssword")
            
            // Act.
            let response = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let accessTokenDto = try response.content.decode(AccessTokenDto.self)
            #expect(accessTokenDto.accessToken != nil, "Access token should exist in response")
            #expect(accessTokenDto.refreshToken != nil, "Refresh token should exist in response")
            #expect(accessTokenDto.accessToken!.count > 0, "Access token should be returned for correct credentials")
            #expect(accessTokenDto.refreshToken!.count > 0, "Refresh token should be returned for correct credentials")
        }
        
        @Test("User with correct credentials should be signed in by username with use cookie")
        func userWithCorrectCredentialsShouldBeSignedInByUsernameWithUseCookie() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "teworfury")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "teworfury", password: "p@ssword", useCookies: true, trustMachine: false)
            
            // Act.
            let response = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let accessTokenDto = try response.content.decode(AccessTokenDto.self)
            #expect(accessTokenDto.accessToken == nil, "Access token should not exist in response")
            #expect(accessTokenDto.refreshToken == nil, "Refresh token should not exist in response")
            #expect(response.headers.setCookie?[Constants.accessTokenName] != nil, "Access token should exists in cookies")
            #expect(response.headers.setCookie?[Constants.refreshTokenName] != nil, "Access token should exists in cookies")
            #expect(response.headers.setCookie?[Constants.isMachineTrustedName] == nil, "Is machine token should not exists in cookies")
            
            #expect(response.headers.setCookie![Constants.accessTokenName]!.string.count > 0, "Access token should be returned for correct credentials")
            #expect(response.headers.setCookie![Constants.refreshTokenName]!.string.count > 0, "Refresh token should be returned for correct credentials")
        }
        
        @Test("User with correct credentials should be signed in by username with use cookie and trusted machine")
        func userWithCorrectCredentialsShouldBeSignedInByUsernameWithUseCookieAndTrustedMachine() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "vobofury")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "vobofury", password: "p@ssword", useCookies: true, trustMachine: true)
            
            // Act.
            let response = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            #expect(response.headers.setCookie?[Constants.isMachineTrustedName] != nil, "Is machine trusted should exists in cookies")
            #expect(response.headers.setCookie![Constants.isMachineTrustedName]!.string.count > 0, "Is machine trusted should be returned for correct credentials")
        }
        
        @Test("Access token should contains basic information about user")
        func accessTokenShouldContainsBasicInformationAboutUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "stevenfury")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "stevenfury@testemail.com", password: "p@ssword")
            
            // Act.
            let response = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let accessTokenDto = try response.content.decode(AccessTokenDto.self)
            
            #expect(accessTokenDto.accessToken != nil, "Access token should exist in response")
            let authorizationPayload = try application.jwt.signers.verify(accessTokenDto.accessToken!, as: UserPayload.self)
            #expect(authorizationPayload.email == user.email, "Email should be included in JWT access token")
            #expect(authorizationPayload.id == user.stringId(), "User id should be included in JWT access token")
            #expect(authorizationPayload.name == user.name, "Name should be included in JWT access token")
            #expect(authorizationPayload.userName == user.userName, "User name should be included in JWT access token")
        }
        
        @Test("Access token should contains information about user roles")
        func accessTokenShouldContainsInformationAboutUserRoles() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "yokofury")
            try await application.attach(user: user, role: Role.administrator)
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "yokofury@testemail.com", password: "p@ssword")
            
            // Act.
            let response = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let accessTokenDto = try response.content.decode(AccessTokenDto.self)
            
            #expect(accessTokenDto.accessToken != nil, "Access token should exist in response")
            let authorizationPayload = try application.jwt.signers.verify(accessTokenDto.accessToken!, as: UserPayload.self)
            #expect(authorizationPayload.roles[0] == Role.administrator, "User roles should be included in JWT access token")
        }
        
        @Test("Last signed date should be updated after login")
        func lastSignedDateShouldBeUpdatedAfterLogin() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "tobyfury")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "tobyfury", password: "p@ssword")
            
            // Act.
            let response = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let user = try await application.getUser(userName: "tobyfury")
            #expect(user.lastLoginDate != nil, "Last login date should be updated after login.")
        }
        
        @Test("User with incorrect password should not be signed in")
        func userWithIncorrectPasswordShouldNotBeSignedIn() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "martafury")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "martafury", password: "incorrect")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/account/login",
                method: .POST,
                data: loginRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "invalidLoginCredentials", "Error code should be equal 'invalidLoginCredentials'.")
        }
        
        @Test("User with not confirmed account should be signed in")
        func userWithNotConfirmedAccountShouldBeSignedIn() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "josefury", emailWasConfirmed: false)
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "josefury", password: "p@ssword")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/account/login",
                method: .POST,
                body: loginRequestDto)
            
            // Assert.
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let accessTokenDto = try response.content.decode(AccessTokenDto.self)
            #expect(accessTokenDto.accessToken != nil, "Access token should exist in response")
            #expect(accessTokenDto.refreshToken != nil, "Refresh token should exist in response")
            #expect(accessTokenDto.accessToken!.count > 0, "Access token should be returned for correct credentials")
            #expect(accessTokenDto.refreshToken!.count > 0, "Refresh token should be returned for correct credentials")
        }
        
        @Test("User with blocked account should not be signed in")
        func userWithBlockedAccountShouldNotBeSignedIn() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "tomfury", isBlocked: true)
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "tomfury", password: "p@ssword")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/account/login",
                method: .POST,
                data: loginRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
        }
        
        @Test("User with not approved account should not be signed in")
        func userWithNotApprovedAccountShouldNotBeSignedIn() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "georgefury", isApproved: false)
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "georgefury", password: "p@ssword")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/account/login",
                method: .POST,
                data: loginRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "userAccountIsNotApproved", "Error code should be equal 'userAccountIsBlocked'.")
        }
        
        @Test("Account should be temporary blocked after five failed login attempts")
        func accountShouldBeTemporaryBlockedAfterFiveFailedLoginAttempts() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "wojciechfury")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "wojciechfury", password: "incorrect")
            
            // Act.
            _ = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            _ = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            _ = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            _ = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            _ = try await application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)

            let errorResponse = try await application.getErrorResponse(
                to: "/account/login",
                method: .POST,
                data: loginRequestDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "loginAttemptsExceeded", "Error code should be equal 'loginAttemptsExceeded'.")
        }
    }
}
