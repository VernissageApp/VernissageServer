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
        
        @Test
        func `User should be muted for authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "johnboby")
            _ = try await application.createUser(userName: "markboby")
            
            // Act.
            let relationshipDto = try await application.getResponse(
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
        
        @Test
        func `Mute should delete direct statuses unfollowed user from timline`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "tobiaszboby", generateKeys: true)
            let user2 = try await application.createUser(userName: "trondboby", generateKeys: true)
            let user3 = try await application.createUser(userName: "wisznaboby", generateKeys: true)
            
            let (statuses2, attachments2) = try await application.createStatuses(user: user2, notePrefix: "Public note user 2", amount: 2)
            let (statuses3, attachments3) = try await application.createStatuses(user: user3, notePrefix: "Public note user 3", amount: 2)
            
            _ = try await application.createUserStatus(type: .follow, user: user1, statuses: statuses2 + statuses3)
            defer {
                application.clearFiles(attachments: attachments2 + attachments3)
            }
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            // Act.
            let relationship = try await application.getResponse(
                as: .user(userName: "tobiaszboby", password: "p@ssword"),
                to: "/users/\(user2.userName)/mute",
                method: .POST,
                data: UserMuteRequestDto(muteStatuses: true,
                                         muteReblogs: true,
                                         muteNotifications: true,
                                         removeStatusesFromTimeline: true,
                                         removeReblogsFromTimeline: false),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.mutedStatuses, "Statuses should be muted.")

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
        func `Mute should delete rebloged statuses unfollowed user from timline`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "aniaboby", generateKeys: true)
            let user2 = try await application.createUser(userName: "moniqaboby", generateKeys: true)
            let user3 = try await application.createUser(userName: "mariolkaboby", generateKeys: true)
            
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
                as: .user(userName: "aniaboby", password: "p@ssword"),
                to: "/users/\(user2.userName)/mute",
                method: .POST,
                data: UserMuteRequestDto(muteStatuses: true,
                                         muteReblogs: true,
                                         muteNotifications: true,
                                         removeStatusesFromTimeline: true,
                                         removeReblogsFromTimeline: false),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.mutedStatuses, "Statuses should be muted.")

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
        func `Mute should delete statuses reblogged by unfollowed user from timline`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "bartoszboby", generateKeys: true)
            let user2 = try await application.createUser(userName: "bolekboby", generateKeys: true)
            let user3 = try await application.createUser(userName: "bigosboby", generateKeys: true)
            let user4 = try await application.createUser(userName: "bohdanboby", generateKeys: true)
            
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
                as: .user(userName: "bartoszboby", password: "p@ssword"),
                to: "/users/\(user2.userName)/mute",
                method: .POST,
                data: UserMuteRequestDto(muteStatuses: true,
                                         muteReblogs: true,
                                         muteNotifications: true,
                                         removeStatusesFromTimeline: false,
                                         removeReblogsFromTimeline: true),
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.mutedStatuses, "Statuses should be muted.")

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
        func `Mute should return not found for not existing user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "eweboby")
            
            // Act.
            let response = try await application.getErrorResponse(
                as: .user(userName: "eweboby", password: "p@ssword"),
                to: "/users/@notexists/mute",
                method: .POST,
                data: UserMuteRequestDto(muteStatuses: true, muteReblogs: true, muteNotifications: true)
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Mute should return unauthorized for not authorized user`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "rickboby")
            
            // Act.
            let response = try await application.getErrorResponse(
                to: "/users/@rickboby/mute",
                method: .POST,
                data: UserMuteRequestDto(muteStatuses: true, muteReblogs: true, muteNotifications: true)
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthoroized (401).")
        }
    }
}
