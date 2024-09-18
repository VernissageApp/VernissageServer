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
    
    @Suite("POST /disable-2fa", .serialized, .tags(.account))
    struct DisableTwoFactorAuthenticationActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Two factor token should be disabled for authorized user with correct token")
        func twoFactorTokenShouldBeDisabledForAuthorizedUserWithCorrectToken() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "markusbiolik")
            let twoFactorTokenDto = try application.getResponse(
                as: .user(userName: "markusbiolik", password: "p@ssword"),
                to: "/account/get-2fa-token",
                method: .GET,
                decodeTo: TwoFactorTokenDto.self
            )
            
            let twoFactorTokensService = TwoFactorTokensService()
            let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)
            
            _ = try application.sendRequest(
                as: .user(userName: "markusbiolik", password: "p@ssword"),
                to: "/account/enable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
            )
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "markusbiolik", password: "p@ssword", token: tokens.first),
                to: "/account/disable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: tokens.last ?? ""]
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        }
        
        @Test("Two factor token should be disabled for authorized user with correct token")
        func twoFactorTokenShouldNotBeDisabledForAuthorizedUserWithIncorrectToken() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "ronaldbiolik")
            let twoFactorTokenDto = try application.getResponse(
                as: .user(userName: "ronaldbiolik", password: "p@ssword"),
                to: "/account/get-2fa-token",
                method: .GET,
                decodeTo: TwoFactorTokenDto.self
            )
            
            let twoFactorTokensService = TwoFactorTokensService()
            let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)
            
            _ = try application.sendRequest(
                as: .user(userName: "ronaldbiolik", password: "p@ssword"),
                to: "/account/enable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
            )
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "ronaldbiolik", password: "p@ssword", token: tokens.first),
                to: "/account/disable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: "444333"]
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Two factor token should be disabled for authorized user with correct token")
        func twoFactorTokenShouldNotBeDisabledForAuthorizedUserWithoutHeader() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "enyabiolik")
            let twoFactorTokenDto = try application.getResponse(
                as: .user(userName: "enyabiolik", password: "p@ssword"),
                to: "/account/get-2fa-token",
                method: .GET,
                decodeTo: TwoFactorTokenDto.self
            )
            
            let twoFactorTokensService = TwoFactorTokensService()
            let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)
            
            _ = try application.sendRequest(
                as: .user(userName: "enyabiolik", password: "p@ssword"),
                to: "/account/enable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
            )
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "enyabiolik", password: "p@ssword", token: tokens.first),
                to: "/account/disable-2fa",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
        }
        
        @Test("Two factor token should be disabled for authorized user with correct token")
        func twoFactorTokenShouldNotBeDisabledForUnauthorizedUser() async throws {
            // Act.
            let response = try application.sendRequest(
                to: "/account/disable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: "12321"]
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
