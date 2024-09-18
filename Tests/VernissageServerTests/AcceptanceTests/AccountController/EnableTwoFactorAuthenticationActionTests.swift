//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import JWT
import Vapor
import Testing

extension AccountControllerTests {
    
    @Suite("POST /enable-2fa", .serialized, .tags(.account))
    struct EnableTwoFactorAuthenticationActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Two factor token should be enabled for authorized user with correct token")
        func twoFactorTokenShouldBeEnabledForAuthorizedUserWithCorrectToken() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "markustebix")
            let twoFactorTokenDto = try application.getResponse(
                as: .user(userName: "markustebix", password: "p@ssword"),
                to: "/account/get-2fa-token",
                method: .GET,
                decodeTo: TwoFactorTokenDto.self
            )
            
            let twoFactorTokensService = TwoFactorTokensService()
            let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "markustebix", password: "p@ssword"),
                to: "/account/enable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        }
        
        @Test("Two factor token should be required during login")
        func twoFactorTokenShouldBeRequiredDuringLogin() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "enridtebix")
            let twoFactorTokenDto = try application.getResponse(
                as: .user(userName: "enridtebix", password: "p@ssword"),
                to: "/account/get-2fa-token",
                method: .GET,
                decodeTo: TwoFactorTokenDto.self
            )
            
            let twoFactorTokensService = TwoFactorTokensService()
            let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)
            
            _ = try application.sendRequest(
                as: .user(userName: "enridtebix", password: "p@ssword"),
                to: "/account/enable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
            )
            
            // Act.
            let response = try application.sendRequest(
                to: "/account/login",
                method: .POST,
                body: LoginRequestDto(userNameOrEmail: "enridtebix", password: "p@ssword"))
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.preconditionRequired, "Response http status code should be preconditionRequired (428).")
        }
        
        @Test("Two factor token should not be enabled for authorized user with incorrect token")
        func twoFactorTokenShouldNotBeEnabledForAuthorizedUserWithIncorrectToken() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "evatebix")
            _ = try application.getResponse(
                as: .user(userName: "evatebix", password: "p@ssword"),
                to: "/account/get-2fa-token",
                method: .GET,
                decodeTo: TwoFactorTokenDto.self
            )
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "evatebix", password: "p@ssword"),
                to: "/account/enable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: "12321"]
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Two factor token should not be enabled for authorized user without header")
        func twoFactorTokenShouldNotBeEnabledForAuthorizedUserWithoutHeader() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "ronaldtebix")
            _ = try application.getResponse(
                as: .user(userName: "ronaldtebix", password: "p@ssword"),
                to: "/account/get-2fa-token",
                method: .GET,
                decodeTo: TwoFactorTokenDto.self
            )
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "ronaldtebix", password: "p@ssword"),
                to: "/account/enable-2fa",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        }
        
        @Test("Two factor token should not be enabled for unauthorized user")
        func twoFactorTokenShouldNotBeEnabledForUnauthorizedUser() async throws {
            // Act.
            let response = try application.sendRequest(
                to: "/account/enable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: "12321"]
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
