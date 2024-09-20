//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("Account (DELETE /account/refresh-token/:username)", .serialized, .tags(.account))
    struct RevokeActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Ok status code should be returned after revoked refresh token by administrator")
        func okStatusCodeShouldBeReturnedAfterRevokedRefreshTokenByAdministrator() async throws {
            // Arrange.
            let admin = try await application.createUser(userName: "annahights")
            try await application.attach(user: admin, role: Role.administrator)
            
            _ = try await application.createUser(userName: "martinhights")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "martinhights", password: "p@ssword")
            _ = try application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "annahights", password: "p@ssword"),
                to: "/account/refresh-token/@martinhights",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        }
        
        @Test("Ok status code should be returned after revoked own refresh token")
        func okStatusCodeShouldBeReturnedAfterRevokedOwnRefreshToken() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "vardyhights")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "vardyhights", password: "p@ssword")
            _ = try application.sendRequest(to: "/account/login", method: .POST, body: loginRequestDto)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "vardyhights", password: "p@ssword"),
                to: "/account/refresh-token/@vardyhights",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        }
        
        @Test("New refresh token should not be returned when old were revoked")
        func newRefreshTokenShouldNotBeReturnedWhenOldWereRevoked() async throws {
            // Arrange.
            let admin = try await application.createUser(userName: "victorhights")
            try await application.attach(user: admin, role: Role.administrator)
            
            _ = try await application.createUser(userName: "lidiahights")
            let loginRequestDto = LoginRequestDto(userNameOrEmail: "lidiahights", password: "p@ssword")
            let accessTokenDto = try application.getResponse(
                to: "/account/login",
                method: .POST,
                data: loginRequestDto,
                decodeTo: AccessTokenDto.self)
            
            // Act.
            _ = try application.sendRequest(
                as: .user(userName: "victorhights", password: "p@ssword"),
                to: "/account/refresh-token/@lidiahights",
                method: .DELETE
            )
            
            let refreshTokenDto = RefreshTokenDto(refreshToken: accessTokenDto.refreshToken!)
            let errorResponse = try application.getErrorResponse(
                to: "/account/refresh-token",
                method: .POST,
                data: refreshTokenDto
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "refreshTokenRevoked", "Error code should be equal 'refreshTokenRevoked'.")
        }
        
        @Test("Not found should be returned when user not exists")
        func notFoundShouldBeReturnedWhenUserNotExists() async throws {
            // Arrange.
            let admin = try await application.createUser(userName: "rickyhights")
            try await application.attach(user: admin, role: Role.administrator)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "rickyhights", password: "p@ssword"),
                to: "/account/refresh-token/@notexists",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unauthorized status code should be returned when user is not authorized")
        func unauthorizedStatusCodeShouldBeReturnedWhenUserIsNotAuthorized() throws {
            // Act.
            let response = try application.sendRequest(
                to: "/account/refresh-token/@user",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
        
        @Test("Forbidden status code should be returned when user is not super user")
        func forbiddenStatusCodeShouldBeReturnedWhenUserIsNotSuperUser() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "michalehights")
            _ = try await application.createUser(userName: "burekhights")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "michalehights", password: "p@ssword"),
                to: "/account/refresh-token/@burekhights",
                method: .DELETE
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
    }
}
