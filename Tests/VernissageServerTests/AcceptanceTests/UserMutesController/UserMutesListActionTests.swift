//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent

extension ControllersTests {
    
    @Suite("UserMutes (GET /user-mutes)", .serialized, .tags(.userMutes))
    struct UserMutesListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `List of muted users should be returned for user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "robinnola")
            let user2 = try await application.createUser(userName: "jozeknola")
            let user3 = try await application.createUser(userName: "annaknola")
            _ = try await application.createUserMute(userId: user1.requireID(),
                                                     mutedUserId: user2.requireID(),
                                                     muteStatuses: true,
                                                     muteReblogs: true,
                                                     muteNotifications: true)
            _ = try await application.createUserMute(userId: user1.requireID(),
                                                     mutedUserId: user3.requireID(),
                                                     muteStatuses: true,
                                                     muteReblogs: true,
                                                     muteNotifications: true)
            
            // Act.
            let userMutes = try await application.getResponse(
                as: .user(userName: "robinnola", password: "p@ssword"),
                to: "/user-mutes",
                method: .GET,
                decodeTo: PaginableResultDto<UserMuteDto>.self
            )
            
            // Assert.
            #expect(userMutes.data.count == 2, "All user muted users should be returned.")
        }
        
        @Test
        func `Only muted users which has been muted by user should be returned`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "gregnola")
            let user2 = try await application.createUser(userName: "eriknola")
            let user3 = try await application.createUser(userName: "karonola")
            let user4 = try await application.createUser(userName: "ulaknola")
            _ = try await application.createUserMute(userId: user1.requireID(),
                                                     mutedUserId: user3.requireID(),
                                                     muteStatuses: true,
                                                     muteReblogs: true,
                                                     muteNotifications: true)
            _ = try await application.createUserMute(userId: user1.requireID(),
                                                     mutedUserId: user4.requireID(),
                                                     muteStatuses: true,
                                                     muteReblogs: true,
                                                     muteNotifications: true)
            _ = try await application.createUserMute(userId: user2.requireID(),
                                                     mutedUserId: user3.requireID(),
                                                     muteStatuses: true,
                                                     muteReblogs: true,
                                                     muteNotifications: true)
            
            // Act.
            let userMutes = try await application.getResponse(
                as: .user(userName: "gregnola", password: "p@ssword"),
                to: "/user-mutes",
                method: .GET,
                decodeTo: PaginableResultDto<UserMuteDto>.self
            )
            
            // Assert.
            #expect(userMutes.data.count == 2, "All user muted users should be returned.")
        }
                        
        @Test
        func `List of muted users should not be returned when user is not authorized`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/user-mutes", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
