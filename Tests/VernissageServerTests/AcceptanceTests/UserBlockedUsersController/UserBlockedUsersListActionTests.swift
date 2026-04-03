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
    
    @Suite("UserBlockedUsers (GET /user-blocked-users)", .serialized, .tags(.userBlockedUsers))
    struct UserBlockedUsersListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `List of blocked users should be returned for user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "robinjola")
            let user2 = try await application.createUser(userName: "jozekjola")
            let user3 = try await application.createUser(userName: "annakjola")
            _ = try await application.createUserBlockedUser(userId: user1.requireID(), blockedUserId: user2.requireID(), reason: "Reason 1")
            _ = try await application.createUserBlockedUser(userId: user1.requireID(), blockedUserId: user3.requireID(), reason: "Reason 2")
            
            // Act.
            let userMutes = try await application.getResponse(
                as: .user(userName: "robinjola", password: "p@ssword"),
                to: "/user-blocked-users",
                method: .GET,
                decodeTo: PaginableResultDto<UserBlockedUserDto>.self
            )
            
            // Assert.
            #expect(userMutes.data.count == 2, "All user blocked users should be returned.")
        }
        
        @Test
        func `Only blocked users which has been blocked by user should be returned`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "gregjola")
            let user2 = try await application.createUser(userName: "erikjola")
            let user3 = try await application.createUser(userName: "karojola")
            let user4 = try await application.createUser(userName: "ulakjola")
            
            _ = try await application.createUserBlockedUser(userId: user1.requireID(), blockedUserId: user3.requireID(), reason: "Reason 1")
            _ = try await application.createUserBlockedUser(userId: user1.requireID(), blockedUserId: user4.requireID(), reason: "Reason 2")
            _ = try await application.createUserBlockedUser(userId: user2.requireID(), blockedUserId: user3.requireID(), reason: "Reason 3")
            
            // Act.
            let userMutes = try await application.getResponse(
                as: .user(userName: "gregjola", password: "p@ssword"),
                to: "/user-blocked-users",
                method: .GET,
                decodeTo: PaginableResultDto<UserBlockedUserDto>.self
            )
            
            // Assert.
            #expect(userMutes.data.count == 2, "All user muted users should be returned.")
        }
                        
        @Test
        func `List of blocked users should not be returned when user is not authorized`() async throws {
            // Act.
            let response = try await application.sendRequest(to: "/user-blocked-users", method: .GET)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
