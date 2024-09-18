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
    
    @Suite("POST /:username/refresh", .serialized, .tags(.users))
    struct UsersRefreshActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("User should be refreshed for authorized user")
        func userShouldBeRefreshedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "johngiboq")
            try await application.attach(user: user1, role: Role.moderator)
            
            _ = try await application.createUser(userName: "markgiboq")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "johngiboq", password: "p@ssword"),
                to: "/users/@markgiboq/refresh",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        }
        
        @Test("User should not be refreshed for regular user")
        func userShouldNotBeRefreshedForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "fredgiboq")
            _ = try await application.createUser(userName: "tidegiboq")
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "fredgiboq", password: "p@ssword"),
                to: "/users/@tidegiboq/refresh",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Refresh should return not found for not existing user")
        func refreshShouldReturnNotFoundForNotExistingUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "ewegiboq")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let response = try application.getErrorResponse(
                as: .user(userName: "ewegiboq", password: "p@ssword"),
                to: "/users/@notexists/refresh",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Refresh should return unauthorized for not authorized user")
        func refreshShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickgiboq")
            
            // Act.
            let response = try application.getErrorResponse(
                to: "/users/@rickderiq/refresh",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
