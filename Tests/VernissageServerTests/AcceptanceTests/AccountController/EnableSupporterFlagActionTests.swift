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
    
    @Suite("Account (POST /account/enable-supporter-flag)", .serialized, .tags(.account))
    struct EnableSupporterFlagActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Supporter flag should be enabled for authorized user who is supporter")
        func supporterFlagShouldBeEnabledForAuthorizedUserWhoIsSupporter() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "markusqueen", isSupporter: true)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "markusqueen", password: "p@ssword"),
                to: "/account/enable-supporter-flag",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userAfterRequest = try await application.getUser(id: user.requireID())!
            #expect(userAfterRequest.isSupporterFlagEnabled == true, "User should have flag enabled.")
        }
        
        @Test("Supporter flag should not be enabled for authorized user who is not supporter")
        func supporterFlagShouldNotBeEnabledForAuthorizedUserWhoIsNotSupporter() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "moniasqueen", isSupporter: false)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "moniasqueen", password: "p@ssword"),
                to: "/account/enable-supporter-flag",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            let userAfterRequest = try await application.getUser(id: user.requireID())!
            #expect(userAfterRequest.isSupporterFlagEnabled == false, "User should have flag disabled.")
        }
        
        @Test("Supporter flag should not be enabled for unauthorized user")
        func twoFactorTokenShouldNotBeEnabledForUnauthorizedUser() async throws {
            // Act.
            let response = try await application.sendRequest(
                to: "/account/enable-supporter-flag",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
