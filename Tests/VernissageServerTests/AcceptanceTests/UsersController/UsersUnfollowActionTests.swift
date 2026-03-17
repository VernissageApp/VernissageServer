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
    
    @Suite("Users (POST /users/:username/unfollow)", .serialized, .tags(.users))
    struct UsersUnfollowActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Unfollow should finish successfully for authorized user`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictordera", generateKeys: true)
            let user2 = try await application.createUser(userName: "mariandera", generateKeys: true)
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            // Act.
            let relationship = try await application.getResponse(
                as: .user(userName: "wictordera", password: "p@ssword"),
                to: "/users/\(user2.userName)/unfollow",
                method: .POST,
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.following == false, "User 1 shouldn't follow User 2.")
        }
        
        @Test
        func `Unfollow should delete direct statuses unfollowed user from timline`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "tobiaszdera", generateKeys: true)
            let user2 = try await application.createUser(userName: "tronddera", generateKeys: true)
            let user3 = try await application.createUser(userName: "wisznadera", generateKeys: true)
            
            let (statuses2, attachments2) = try await application.createStatuses(user: user2, notePrefix: "Public note user 2", amount: 2)
            let (statuses3, attachments3) = try await application.createStatuses(user: user3, notePrefix: "Public note user 3", amount: 2)
            
            _ = try await application.createUserStatus(type: .follow, user: user1, statuses: statuses2 + statuses3)
            defer {
                application.clearFiles(attachments: attachments2 + attachments3)
            }
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            // Act.
            let relationship = try await application.getResponse(
                as: .user(userName: "tobiaszdera", password: "p@ssword"),
                to: "/users/\(user2.userName)/unfollow",
                method: .POST,
                data: UnfollowRequestDto(removeStatusesFromTimeline: true, removeReblogsFromTimeline: false),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            let userStatuses = try await application.getAllUserStatuses(forUser: user1.requireID())
            #expect(relationship.following == false, "User 1 shouldn't follow User 2.")
            #expect(userStatuses.count == 2, "Statuses from user 2 should be removed from user's timeline.")
            #expect(
                userStatuses.count { userStatus in
                    statuses3.contains(where: { $0.id == userStatus.$status.id })
                } == 2,
                "Only statuses belonging to user 3 should be visible on user1 timeline."
            )
        }
        
        @Test
        func `Unfollow should delete rebloged statuses unfollowed user from timline`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "aniadera", generateKeys: true)
            let user2 = try await application.createUser(userName: "moniqadera", generateKeys: true)
            let user3 = try await application.createUser(userName: "mariolkadera", generateKeys: true)
            
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
                as: .user(userName: "aniadera", password: "p@ssword"),
                to: "/users/\(user2.userName)/unfollow",
                method: .POST,
                data: UnfollowRequestDto(removeStatusesFromTimeline: true, removeReblogsFromTimeline: false),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            let userStatuses = try await application.getAllUserStatuses(forUser: user1.requireID())
            #expect(relationship.following == false, "User 1 shouldn't follow User 2.")
            #expect(userStatuses.count == 2, "Statuses from user 2 should be removed from user's timeline.")
            #expect(
                userStatuses.count { userStatus in
                    statuses3.contains(where: { $0.id == userStatus.$status.id })
                } == 2,
                "Only statuses belonging to user 3 should be visible on user1 timeline."
            )
        }
        
        @Test
        func `Unfollow should delete statuses reblogged by unfollowed user from timline`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "bartoszdera", generateKeys: true)
            let user2 = try await application.createUser(userName: "bolekdera", generateKeys: true)
            let user3 = try await application.createUser(userName: "bigosdera", generateKeys: true)
            let user4 = try await application.createUser(userName: "bohdandera", generateKeys: true)
            
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
                as: .user(userName: "bartoszdera", password: "p@ssword"),
                to: "/users/\(user2.userName)/unfollow",
                method: .POST,
                data: UnfollowRequestDto(removeStatusesFromTimeline: false, removeReblogsFromTimeline: true),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            let userStatuses = try await application.getAllUserStatuses(forUser: user1.requireID())
            #expect(relationship.following == false, "User 1 shouldn't follow User 2.")
            #expect(userStatuses.count == 2, "Statuses from user 2 should be removed from user's timeline.")
            #expect(
                userStatuses.count { userStatus in
                    statuses3.contains(where: { $0.id == userStatus.$status.id })
                } == 2,
                "Only statuses belonging to user 3 should be visible on user1 timeline."
            )
        }
        
        @Test
        func `Unfollow requests approve should fail for unauthorized user`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "hermandera", generateKeys: true)
            let user2 = try await application.createUser(userName: "robinedera", generateKeys: true)
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/users/\(user2.userName)/unfollow",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
