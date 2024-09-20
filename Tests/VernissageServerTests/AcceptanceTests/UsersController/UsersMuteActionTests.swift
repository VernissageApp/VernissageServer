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
    
    @Suite("Users (POST /users/:username/mute)", .serialized, .tags(.users))
    struct UsersMuteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("User should be muted for authorized user")
        func userShouldBeMutedForAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "johnboby")
            _ = try await application.createUser(userName: "markboby")
            
            // Act.
            let relationshipDto = try application.getResponse(
                as: .user(userName: "johnboby", password: "p@ssword"),
                to: "/users/@markboby/mute",
                method: .POST,
                data: UserMuteRequestDto(muteStatuses: true, muteReblogs: true, muteNotifications: true),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationshipDto.mutedStatuses, "Statuses should be muted.")
            #expect(relationshipDto.mutedReblogs, "Reblogs should be muted.")
            #expect(relationshipDto.mutedNotifications, "Notifications should be muted.")
        }
        
        @Test("Mute should return not found for not existing user")
        func muteShouldReturnNotFoundForNotExistingUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "eweboby")
            
            // Act.
            let response = try application.getErrorResponse(
                as: .user(userName: "eweboby", password: "p@ssword"),
                to: "/users/@notexists/mute",
                method: .POST,
                data: UserMuteRequestDto(muteStatuses: true, muteReblogs: true, muteNotifications: true)
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test("Mute should return unauthorized for not authorized user")
        func muteShouldReturnUnauthorizedForNotAuthorizedUser() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickboby")
            
            // Act.
            let response = try application.getErrorResponse(
                to: "/users/@rickboby/mute",
                method: .POST,
                data: UserMuteRequestDto(muteStatuses: true, muteReblogs: true, muteNotifications: true)
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
