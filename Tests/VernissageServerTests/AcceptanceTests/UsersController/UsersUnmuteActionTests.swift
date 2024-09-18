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
    
    @Suite("POST /:username/unmute", .serialized, .tags(.users))
    struct UsersUnmuteActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("User should be unmuted for authorized user")
        func userShouldBeUnmutedForAuthorizedUser() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "johnvorx")
            let user2  = try await application.createUser(userName: "markvorx")
            _ = try await application.createUserMute(userId: user1.requireID(), mutedUserId: user2.requireID(), muteStatuses: true, muteReblogs: true, muteNotifications: true)
            
            // Act.
            let relationshipDto = try application.getResponse(
                as: .user(userName: "johnvorx", password: "p@ssword"),
                to: "/users/@markvorx/unmute",
                method: .POST,
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationshipDto.mutedStatuses == false, "Statuses should be muted.")
            #expect(relationshipDto.mutedReblogs == false, "Reblogs should be muted.")
            #expect(relationshipDto.mutedNotifications == false, "Notifications should be muted.")
        }
        
        @Test("Unmute should return not found for not existing user")
        func unmuteShouldReturnNotFoundForNotExistingUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "ewevorx")
            
            // Act.
            let response = try application.getErrorResponse(
                as: .user(userName: "ewevorx", password: "p@ssword"),
                to: "/users/@notexists/unmute",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Unmute should return unauthorized for not authorized user")
        func unmuteShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickvorx")
            
            // Act.
            let response = try application.getErrorResponse(
                to: "/users/@rickvorx/unmute",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
