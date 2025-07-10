//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import JWT
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("Users (POST /users/:username/disable-2fa)", .serialized, .tags(.users))
    struct UsersDisableTwoFactorAuthenticationActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Two factor token should be disabled for authorized user")
        func twoFactorTokenShouldBeDisabledForAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "markustrampik")

            let user = try await application.createUser(userName: "trondtrampik")
            try await application.attach(user: user, role: Role.moderator)
            
            let twoFactorTokenDto = try await application.getResponse(
                as: .user(userName: "markustrampik", password: "p@ssword"),
                to: "/account/get-2fa-token",
                method: .GET,
                decodeTo: TwoFactorTokenDto.self
            )
            
            let twoFactorTokensService = TwoFactorTokensService()
            let tokens = try twoFactorTokensService.generateTokens(key: twoFactorTokenDto.key)
            
            _ = try await application.sendRequest(
                as: .user(userName: "markustrampik", password: "p@ssword"),
                to: "/account/enable-2fa",
                method: .POST,
                headers: [ Constants.twoFactorTokenHeader: tokens.first ?? ""]
            )
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "trondtrampik", password: "p@ssword", token: tokens.first),
                to: "/users/@markustrampik/disable-2fa",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        }
       
        @Test("Two factor token should not be disabled for regular user")
        func userShouldNotBeEnabledForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "fredtrampik")
            _ = try await application.createUser(userName: "tidetrampik")
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "fredtrampik", password: "p@ssword"),
                to: "/users/@tidetrampik/disable-2fa",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Two factor token should not be disabled for unauthorized user")
        func twoFactorTokenShouldNotBeDisabledForUnauthorizedUser() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "rubytrampik")

            // Act.
            let response = try await application.sendRequest(
                to: "/users/@rubytrampik/disable-2fa",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
