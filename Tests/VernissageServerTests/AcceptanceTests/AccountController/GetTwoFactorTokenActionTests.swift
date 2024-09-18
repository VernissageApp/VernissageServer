//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing

extension AccountControllerTests {
    
    @Suite("GET /get-2fa-token", .serialized, .tags(.account))
    struct GetTwoFactorTokenActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Two factor token should be generated for authorized user")
        func twoFactorTokenShouldBeGeneratedForAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "markusronfil")
            
            // Act.
            let twoFactorTokenDto = try application.getResponse(
                as: .user(userName: "markusronfil", password: "p@ssword"),
                to: "/account/get-2fa-token",
                method: .GET,
                decodeTo: TwoFactorTokenDto.self
            )
            
            // Assert.
            #expect(twoFactorTokenDto != nil, "New 2FA token should be generated")
            #expect(twoFactorTokenDto.key != nil, "Key in 2FA token should be generated")
            #expect(twoFactorTokenDto.backupCodes != nil, "Backup codes in 2FA token should be generated")
        }
        
        @Test("Two factor token should not be generated for unauthorized user")
        func twoFactorTokenShouldNotBeGeneratedForUnauthorizedUser() async throws {
            // Act.
            let response = try application.sendRequest(to: "/account/get-2fa-token", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
