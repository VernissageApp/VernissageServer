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
    
    @Suite("Users (POST /users/:username/unblock)", .serialized, .tags(.users))
    struct UsersUnblockActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `User should be unblocked for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "johnquartz")
            let user2  = try await application.createUser(userName: "markquartz")
            _ = try await application.createUserBlockedUser(userId: user1.requireID(), blockedUserId: user2.requireID(), reason: "Reason...")
            
            // Act.
            let relationshipDto = try await application.getResponse(
                as: .user(userName: "johnquartz", password: "p@ssword"),
                to: "/users/@markquartz/unblock",
                method: .POST,
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationshipDto.blocked == false, "User should be unblocked.")
        }
        
        @Test
        func `Unblock should return not found for not existing user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "ewequarts")
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "ewequarts", password: "p@ssword"),
                to: "/users/@notexists/unblock",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Unblock should return unauthorized for not authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickquartz")
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/users/@rickquartz/unblock",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
