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

@Suite("POST /:username/enable", .serialized, .tags(.users))
struct UsersEnableActionTests {
    var application: Application!

    init() async throws {
        try await ApplicationManager.shared.initApplication()
        self.application = await ApplicationManager.shared.application
    }

    @Test("User should be enabled for authorized user")
    func userShouldBeEnabledForAuthorizedUser() async throws {
        
        // Arrange.
        let user1 = try await application.createUser(userName: "johnervin")
        try await application.attach(user: user1, role: Role.moderator)

        let user2 = try await application.createUser(userName: "markervin", isBlocked: true)
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "johnervin", password: "p@ssword"),
            to: "/users/@markervin/enable",
            method: .POST
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userAfterRequest = try await application.getUser(id: user2.requireID())!
        #expect(userAfterRequest.isBlocked == false, "User should be unblocked.")
    }
    
    @Test("User should not be enabled for regular user")
    func userShouldNotBeEnabledForRegularUser() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "fredervin")
        _ = try await application.createUser(userName: "tideervin", isBlocked: true)
        
        // Act.
        let response = try application.sendRequest(
            as: .user(userName: "fredervin", password: "p@ssword"),
            to: "/users/@tideervin/enable",
            method: .POST
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }
    
    @Test("Enable should return not found for not existing user")
    func enableShouldReturnNotFoundForNotExistingUser() async throws {
        
        // Arrange.
        let user = try await application.createUser(userName: "eweervin")
        try await application.attach(user: user, role: Role.moderator)
        
        // Act.
        let response = try application.getErrorResponse(
            as: .user(userName: "eweervin", password: "p@ssword"),
            to: "/users/@notexists/enable",
            method: .POST
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }
    
    @Test("Enable should return unauthorized for not authorized user")
    func enableShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
        
        // Arrange.
        _ = try await application.createUser(userName: "rickervin")
        
        // Act.
        let response = try application.getErrorResponse(
            to: "/users/@rickervin/enable",
            method: .POST
        )
        
        // Assert.
        #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
    }
}
