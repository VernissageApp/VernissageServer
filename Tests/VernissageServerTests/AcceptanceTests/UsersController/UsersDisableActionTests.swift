//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension UsersControllerTests {
    
    @Suite("POST /:username/disable", .serialized, .tags(.users))
    struct UsersDisableActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("User should be disabled for authorized user")
        func userShouldBeDisabledForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "johngonter")
            try await application.attach(user: user1, role: Role.moderator)
            
            let user2 = try await application.createUser(userName: "markgonter", isBlocked: false)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "johngonter", password: "p@ssword"),
                to: "/users/@markgonter/disable",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userAfterRequest = try await application.getUser(id: user2.requireID())!
            #expect(userAfterRequest.isBlocked, "User should be blocked.")
        }
        
        @Test("User should not be disabled for regular user")
        func userShouldNotBeDisabledForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "fredgonter")
            _ = try await application.createUser(userName: "tidegonter", isBlocked: true)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "fredgonter", password: "p@ssword"),
                to: "/users/@tideervin/disable",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Disable should return not found for not existing user")
        func disableShouldReturnNotFoundForNotExistingUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "ewegonter")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let response = try application.getErrorResponse(
                as: .user(userName: "ewegonter", password: "p@ssword"),
                to: "/users/@notexists/disable",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Disable should return unauthorized for not authorized user")
        func disableShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickgonter")
            
            // Act.
            let response = try application.getErrorResponse(
                to: "/users/@rickgonter/disable",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
