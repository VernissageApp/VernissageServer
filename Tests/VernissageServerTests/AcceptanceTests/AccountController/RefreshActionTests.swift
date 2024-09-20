//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("Account (POST /account/refresh-token)", .serialized, .tags(.account))
    struct RefreshActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("New tokens should be returned when old refresh token is valid")
        func newTokensShouldBeReturnedWhenOldRefreshTokenIsValid() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "sandragreen")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "sandragreen", password: "p@ssword")
            let accessTokenDto = try application.getResponse(
                to: "/account/login",
                method: .POST,
                data: loginRequestDto,
                decodeTo: AccessTokenDto.self)
            let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!)
            
            // Act.
            let newRefreshTokenDto = try application
                .getResponse(to: "/account/refresh-token", method: .POST, data: refreshTokenDto, decodeTo: AccessTokenDto.self)
            
            // Assert.
            #expect(newRefreshTokenDto.refreshToken != nil, "Refresh token should not exist in response")
            #expect(newRefreshTokenDto.refreshToken!.count > 0, "New refresh token wasn't created.")
        }
        
        @Test("New tokens should be returned when old refresh token is valid with use cookies")
        func newTokensShouldBeReturnedWhenOldRefreshTokenIsValidWithUseCookies() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "tobiszgreen")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "tobiszgreen", password: "p@ssword")
            let accessTokenDto = try application.getResponse(
                to: "/account/login",
                method: .POST,
                data: loginRequestDto,
                decodeTo: AccessTokenDto.self)
            let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!, useCookies: true)
            
            // Act.
            let response = try application
                .sendRequest(to: "/account/refresh-token", method: .POST, body: refreshTokenDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let newRefreshTokenDto = try response.content.decode(AccessTokenDto.self)
            
            #expect(newRefreshTokenDto.accessToken == nil, "Access token should not exist in response")
            #expect(newRefreshTokenDto.refreshToken == nil, "Refresh token should not exist in response")
            #expect(response.headers.setCookie?[Constants.accessTokenName] != nil, "Access token should exists in cookies")
            #expect(response.headers.setCookie?[Constants.refreshTokenName] != nil, "Access token should exists in cookies")
            #expect(response.headers.setCookie![Constants.accessTokenName]!.string.count > 0, "Access token should be returned for correct credentials")
            #expect(response.headers.setCookie![Constants.refreshTokenName]!.string.count > 0, "Refresh token should be returned for correct credentials")
        }
        
        @Test("New tokens should be returned when old refresh token is valid without regeneration")
        func newTokensShouldBeReturnedWhenOldRefreshTokenIsValidWithoutRegeneration() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "trenixgreen")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "trenixgreen", password: "p@ssword")
            let accessTokenDto = try application.getResponse(
                to: "/account/login",
                method: .POST,
                data: loginRequestDto,
                decodeTo: AccessTokenDto.self)
            let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!, regenerateRefreshToken: false)
            
            // Act.
            let response = try application
                .sendRequest(to: "/account/refresh-token", method: .POST, body: refreshTokenDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let newRefreshTokenDto = try response.content.decode(AccessTokenDto.self)
            
            #expect(newRefreshTokenDto.accessToken != nil, "Access token should not exist in response")
            #expect(newRefreshTokenDto.refreshToken != nil, "Refresh token should not exist in response")
            #expect(newRefreshTokenDto.refreshToken == refreshTokenDto.refreshToken, "Refresh token valus should noe be regenerated.")
        }
        
        @Test("New tokens should not be returned when old refresh token is not valid")
        func newTokensShouldNotBeReturnedWhenOldRefreshTokenIsNotValid() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "johngreen")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "johngreen", password: "p@ssword")
            let accessTokenDto = try application.getResponse(
                to: "/account/login",
                method: .POST,
                data: loginRequestDto,
                decodeTo: AccessTokenDto.self)
            let refreshTokenDto = RefreshTokenDto(refreshToken: "\(accessTokenDto.refreshToken ?? "")00")
            
            // Act.
            let response = try application
                .sendRequest(to: "/account/refresh-token", method: .POST, body: refreshTokenDto)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("New tokens should not be returned when old refresh token is valid but user is blocked")
        func newTokensShouldNotBeReturnedWhenOldRefreshTokenIsValidButUserIsBlocked() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "timothygreen")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "timothygreen", password: "p@ssword")
            let accessTokenDto = try application
                .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)
            
            user.isBlocked = true
            try await user.save(on: application.db)
            let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!)
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/account/refresh-token",
                method: .POST,
                data: refreshTokenDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "userAccountIsBlocked", "Error code should be equal 'userAccountIsBlocked'.")
        }
        
        @Test("New tokens should not be returned when old refresh token is expired")
        func newTokensShouldNotBeReturnedWhenOldRefreshTokenIsExpired() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "wandagreen")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "wandagreen", password: "p@ssword")
            let accessTokenDto = try application
                .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)
            
            let refreshToken = try await application.getRefreshToken(token: accessTokenDto.refreshToken!)
            refreshToken.expiryDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
            try await refreshToken.save(on: application.db)
            
            let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!)
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/account/refresh-token",
                method: .POST,
                data: refreshTokenDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "refreshTokenExpired", "Error code should be equal 'refreshTokenExpired'.")
        }
        
        @Test("New tokens should not be returned when old refresh token is revoked")
        func newTokensShouldNotBeReturnedWhenOldRefreshTokenIsRevoked() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "alexagreen")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "alexagreen", password: "p@ssword")
            let accessTokenDto = try application
                .getResponse(to: "/account/login", method: .POST, data: loginRequestDto, decodeTo: AccessTokenDto.self)
            
            let refreshToken = try await application.getRefreshToken(token: accessTokenDto.refreshToken!)
            refreshToken.revoked = true
            try await refreshToken.save(on: application.db)
            
            let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!)
            
            // Act.
            let errorResponse = try application.getErrorResponse(
                to: "/account/refresh-token",
                method: .POST,
                data: refreshTokenDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidde (403).")
            #expect(errorResponse.error.code == "refreshTokenRevoked", "Error code should be equal 'refreshTokenRevoked'.")
        }
    }
}
