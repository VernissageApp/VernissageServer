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
    
    @Suite("Users (POST /users/:username/unsuppress)", .serialized, .tags(.users))
    struct UsersUnsuppressActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `User should be unsuppressed for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "johnunsuppress")
            try await application.attach(user: user1, role: Role.moderator)
            
            let user2 = try await application.createUser(userName: "markunsuppress", isSuppressed: true)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "johnunsuppress", password: "p@ssword"),
                to: "/users/@markunsuppress/unsuppress",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userAfterRequest = try #require(await application.getUser(id: user2.requireID()))
            #expect(userAfterRequest.isSuppressed == false, "User should not be suppressed.")
        }
        
        @Test
        func `User should not be unsuppressed for regular user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "fredunsuppress")
            _ = try await application.createUser(userName: "tideunsuppress", isSuppressed: true)
            
            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: "fredunsuppress", password: "p@ssword"),
                to: "/users/@tideunsuppress/unsuppress",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test
        func `Unsuppress should return not found for not existing user`() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "eweunsuppress")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "eweunsuppress", password: "p@ssword"),
                to: "/users/@notexists/unsuppress",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Unsuppress should return unauthorized for not authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickunsuppress")
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/users/@rickunsuppress/unsuppress",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
