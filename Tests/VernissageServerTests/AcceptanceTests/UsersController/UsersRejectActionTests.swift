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
    
    @Suite("POST /:username/reject", .serialized, .tags(.users))
    struct UsersRejectActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("User should be rejected for authorized user")
        func userShouldBeRejectedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "johnrusq")
            try await application.attach(user: user1, role: Role.moderator)
            
            let user2 = try await application.createUser(userName: "markrusq", isApproved: false)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "johnrusq", password: "p@ssword"),
                to: "/users/@markrusq/reject",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            let userAfterRequest = try await application.getUser(id: user2.requireID(), withDeleted: true)
            #expect(userAfterRequest == nil, "User should be deleted completly from database.")
        }
        
        @Test("User should not be rejected for regular user")
        func userShouldNotBeRejectedForRegularUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "fredrusq")
            _ = try await application.createUser(userName: "tiderusq", isApproved: false)
            
            // Act.
            let response = try application.sendRequest(
                as: .user(userName: "fredrusq", password: "p@ssword"),
                to: "/users/@tiderusq/reject",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test("Reject should return not found for not existing user")
        func rejectShouldReturnNotFoundForNotExistingUser() async throws {
            
            // Arrange.
            let user = try await application.createUser(userName: "ewerusq")
            try await application.attach(user: user, role: Role.moderator)
            
            // Act.
            let response = try application.getErrorResponse(
                as: .user(userName: "ewerusq", password: "p@ssword"),
                to: "/users/@notexists/reject",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Reject should return unauthorized for not authorized user")
        func rejectShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickrusq")
            
            // Act.
            let response = try application.getErrorResponse(
                to: "/users/@rickderiq/reject",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
