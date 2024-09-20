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

extension ControllersTests {
    
    @Suite("Users (POST /users/:username/approve)", .serialized, .tags(.users))
    struct UsersApproveActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User should be approved for authorized user")
        func userShouldBeApprovedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "johnderiq")
            try await application.attach(user: user1, role: Role.moderator)
            
            let user2 = try await application.createUser(userName: "markderiq", isApproved: false)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "johnderiq", password: "p@ssword"),
                to: "/users/@markderiq/approve",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userAfterRequest = try await application.getUser(id: user2.requireID())!
            #expect(userAfterRequest.isApproved, "User should be approved.")
        }
        
        @Test("User should not be approved for regular user")
        func userShouldNotBeApprovedForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "fredderiq")
            _ = try await application.createUser(userName: "tidederiq", isApproved: false)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "fredderiq", password: "p@ssword"),
                to: "/users/@tidederiq/approve",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Approve should return not found for not existing user")
        func approveShouldReturnNotFoundForNotExistingUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "ewederiq")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let response = try application.getErrorResponse(
                as: .user(userName: "ewederiq", password: "p@ssword"),
                to: "/users/@notexists/approve",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Approve should return unauthorized for not authorized user")
        func approveShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickderiq")
            
            // Act.
            let response = try application.getErrorResponse(
                to: "/users/@rickderiq/approve",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
