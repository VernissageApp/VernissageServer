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
    
    @Suite("Users (POST /users/:username/supporter)", .serialized, .tags(.users))
    struct UsersSupporterActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User should be mark as supporter for authorized user")
        func userShouldBeMarkAsSupporterForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "johnfriq")
            try await application.attach(user: user1, role: Role.moderator)
            
            let user2 = try await application.createUser(userName: "markfriq", isSupporter: false)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "johnfriq", password: "p@ssword"),
                to: "/users/@markfriq/supporter",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userAfterRequest = try await application.getUser(id: user2.requireID())!
            #expect(userAfterRequest.isSupporter == true, "User should be mark as supporter.")
        }
        
        @Test("User should not be mark as supporter for regular user")
        func userShouldNotBeMarkAsSupporterForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "fredfriq")
            _ = try await application.createUser(userName: "tidefriq", isSupporter: false)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "fredfriq", password: "p@ssword"),
                to: "/users/@tidefriq/supporter",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Mark as supporter should return not found for not existing user")
        func markAsSupporterShouldReturnNotFoundForNotExistingUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "ewefriq")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "ewefriq", password: "p@ssword"),
                to: "/users/@notexists/supporter",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Mark as supporter should return unauthorized for not authorized user")
        func markAsSupporterShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickfriq")
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/users/@rickfriq/supporter",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
