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
    
    @Suite("Users (POST /users/:username/block)", .serialized, .tags(.users))
    struct UsersBlockActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `User should be blocked for authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "johnbibi")
            _ = try await application.createUser(userName: "markbibi")
            
            // Act.
            let relationshipDto = try await application.getResponse(
                as: .user(userName: "johnbibi", password: "p@ssword"),
                to: "/users/@markbibi/block",
                method: .POST,
                data: UserBlockRequestDto(reason: "I don't like him."),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationshipDto.blocked, "User should be blocked.")
        }
        
        @Test
        func `Block should delete direct statuses blocked user from timline`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "tobiaszbibi", generateKeys: true)
            let user2 = try await application.createUser(userName: "trondbibi", generateKeys: true)
            let user3 = try await application.createUser(userName: "wisznabibi", generateKeys: true)
            
            let (statuses2, attachments2) = try await application.createStatuses(user: user2, notePrefix: "Public note user 2", amount: 2)
            let (statuses3, attachments3) = try await application.createStatuses(user: user3, notePrefix: "Public note user 3", amount: 2)
            
            _ = try await application.createUserStatus(type: .follow, user: user1, statuses: statuses2 + statuses3)
            defer {
                application.clearFiles(attachments: attachments2 + attachments3)
            }
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            // Act.
            let relationship = try await application.getResponse(
                as: .user(userName: "tobiaszbibi", password: "p@ssword"),
                to: "/users/@trondbibi/block",
                method: .POST,
                data: UserBlockRequestDto(reason: "Reason..."),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.blocked, "User should be blocked.")
            #expect(relationship.following == false, "User should not follow blocked user.")

            let userStatuses = try await application.getAllUserStatuses(forUser: user1.requireID())
            #expect(userStatuses.count == 2, "Statuses from user 2 should be removed from user's timeline.")
            #expect(
                userStatuses.count { userStatus in
                    statuses3.contains(where: { $0.id == userStatus.$status.id })
                } == 2,
                "Only statuses belonging to user 3 should be visible on user1 timeline."
            )
        }
        
        @Test
        func `Block should delete rebloged statuses blocked user from timline`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "aniabibi", generateKeys: true)
            let user2 = try await application.createUser(userName: "moniqabibi", generateKeys: true)
            let user3 = try await application.createUser(userName: "mariolkabibi", generateKeys: true)
            
            let (statuses2, attachments2) = try await application.createStatuses(user: user2, notePrefix: "Public note user 2", amount: 2)
            let (statuses3, attachments3) = try await application.createStatuses(user: user3, notePrefix: "Public note user 3", amount: 2)
            
            let reblogedStatus = try await application.reblogStatus(user: user3, status: statuses2.first!)
            
            _ = try await application.createUserStatus(type: .follow, user: user1, statuses: statuses3 + [reblogedStatus])
            defer {
                application.clearFiles(attachments: attachments2 + attachments3)
            }
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            // Act.
            let relationship = try await application.getResponse(
                as: .user(userName: "aniabibi", password: "p@ssword"),
                to: "/users/@moniqabibi/block",
                method: .POST,
                data: UserBlockRequestDto(reason: "Reason..."),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.blocked, "User should be blocked.")
            #expect(relationship.following == false, "User should not follow blocked user.")

            let userStatuses = try await application.getAllUserStatuses(forUser: user1.requireID())
            #expect(userStatuses.count == 2, "Statuses from user 2 should be removed from user's timeline.")
            #expect(
                userStatuses.count { userStatus in
                    statuses3.contains(where: { $0.id == userStatus.$status.id })
                } == 2,
                "Only statuses belonging to user 3 should be visible on user1 timeline."
            )
        }
        
        @Test
        func `Block should delete statuses reblogged by blocked user from timline`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "bartoszbibi", generateKeys: true)
            let user2 = try await application.createUser(userName: "bolekbibi", generateKeys: true)
            let user3 = try await application.createUser(userName: "bigosbibi", generateKeys: true)
            let user4 = try await application.createUser(userName: "bohdanbibi", generateKeys: true)
            
            let (statuses3, attachments3) = try await application.createStatuses(user: user3, notePrefix: "Public note user 3", amount: 2)
            let (statuses4, attachments4) = try await application.createStatuses(user: user4, notePrefix: "Public note user 4", amount: 2)
            
            let reblogedStatus = try await application.reblogStatus(user: user2, status: statuses4.first!)
            
            _ = try await application.createUserStatus(type: .follow, user: user1, statuses: statuses3 + [reblogedStatus])
            defer {
                application.clearFiles(attachments: attachments3 + attachments4)
            }
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            // Act.
            let relationship = try await application.getResponse(
                as: .user(userName: "bartoszbibi", password: "p@ssword"),
                to: "/users/@bolekbibi/block",
                method: .POST,
                data: UserBlockRequestDto(reason: "Reason..."),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.blocked, "User should be blocked.")
            #expect(relationship.following == false, "User should not follow blocked user.")

            let userStatuses = try await application.getAllUserStatuses(forUser: user1.requireID())
            #expect(userStatuses.count == 2, "Statuses from user 2 should be removed from user's timeline.")
            #expect(
                userStatuses.count { userStatus in
                    statuses3.contains(where: { $0.id == userStatus.$status.id })
                } == 2,
                "Only statuses belonging to user 3 should be visible on user1 timeline."
            )
        }
        
        @Test
        func `Block should return not found for not existing user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "ewebibi")
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "ewebibi", password: "p@ssword"),
                to: "/users/@notexists/block",
                method: .POST,
                data: UserBlockRequestDto(reason: "Reason..."),
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Block should return unauthorized for not authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickbibi")
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/users/@rickbibi/block",
                method: .POST,
                data: UserBlockRequestDto(reason: "Reason..."),
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
