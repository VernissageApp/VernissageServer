//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("Users (POST /users/:username/not-supporter)", .serialized, .tags(.users))
    struct UsersNotSupporterActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User should be mark as not supporter for authorized user")
        func userShouldBeMarkAsNotSupporterForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "johnkrol")
            try await application.attach(user: user1, role: Role.moderator)
            
            let user2 = try await application.createUser(userName: "markkrol", isSupporter: true)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "johnkrol", password: "p@ssword"),
                to: "/users/@markkrol/not-supporter",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userAfterRequest = try await application.getUser(id: user2.requireID())!
            #expect(userAfterRequest.isSupporter == false, "User should be mark as not supporter.")
        }
        
        @Test("User should not be mark as not supporter for regular user")
        func userShouldNotBeMarkAsNotSupporterForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "fredkrol")
            _ = try await application.createUser(userName: "tidekrol", isSupporter: false)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "fredkrol", password: "p@ssword"),
                to: "/users/@tidekrol/not-supporter",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Mark as not supporter should return not found for not existing user")
        func markAsNotSupporterShouldReturnNotFoundForNotExistingUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "ewekrol")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "ewekrol", password: "p@ssword"),
                to: "/users/@notexists/not-supporter",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Mark as not supporter should return unauthorized for not authorized user")
        func markAsNotSupporterShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickkrol")
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/users/@rickkrol/not-supporter",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
