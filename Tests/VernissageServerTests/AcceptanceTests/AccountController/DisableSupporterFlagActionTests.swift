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
    
    @Suite("Account (POST /account/disable-supporter-flag)", .serialized, .tags(.account))
    struct DisableSupporterFlagActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Supporter flag should be disabled for authorized user")
        func supporterFlagShouldBeDisabledForAuthorizedUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "markusbenny", isSupporter: true, isSupporterFlagEnabled: true)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "markusbenny", password: "p@ssword"),
                to: "/account/disable-supporter-flag",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userAfterRequest = try await application.getUser(id: user.requireID())!
            #expect(userAfterRequest.isSupporterFlagEnabled == false, "User should have flag disabled.")
        }
        
        @Test("Supporter flag should not be disabled for unauthorized user")
        func twoFactorTokenShouldNotBeEnabledForUnauthorizedUser() async throws {
            // Act.
            let response = try await application.sendRequest(
                to: "/account/disable-supporter-flag",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
