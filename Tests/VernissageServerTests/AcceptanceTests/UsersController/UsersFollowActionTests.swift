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
    
    @Suite("Users (POST /users/:username/follow)", .serialized, .tags(.users))
    struct UsersFollowActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Follow should finish successfully for authorized user`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictorerst", generateKeys: true)
            let user2 = try await application.createUser(userName: "marianerst", generateKeys: true)
            
            // Act.
            let relationship = try await application.getResponse(
                as: .user(userName: "wictorerst", password: "p@ssword"),
                to: "/users/\(user2.userName)/follow",
                method: .POST,
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.following, "User 1 is following now User 2.")
            
            let notification = try await application.getNotification(type: .follow, to: user2.requireID(), by: user1.requireID(), statusId: nil)
            #expect(notification != nil, "Notification should be added.")
        }
        
        @Test
        func `Follow should be requested for manual approval`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "annaerst", generateKeys: true)
            let user2 = try await application.createUser(userName: "karinerst", manuallyApprovesFollowers: true, generateKeys: true)
            
            // Act.
            let relationship = try await application.getResponse(
                as: .user(userName: "annaerst", password: "p@ssword"),
                to: "/users/\(user2.userName)/follow",
                method: .POST,
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.following == false, "User 1 is following now User 2.")
            #expect(relationship.requested, "User 1 is requesting follow User 2.")
            
            let notification = try await application.getNotification(type: .followRequest, to: user2.requireID(), by: user1.requireID(), statusId: nil)
            #expect(notification != nil, "Notification should be added.")
        }
        
        @Test
        func `Follow should be forbidden when target account has movedTo set`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wolverst", generateKeys: true)
            let user2 = try await application.createUser(userName: "starekonto", generateKeys: true)
            let user3 = try await application.createUser(userName: "nowekonto", generateKeys: true)
            user2.$movedTo.id = try user3.requireID()
            try await user2.save(on: application.db)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: user1.userName, password: "p@ssword"),
                to: "/users/\(user2.userName)/follow",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
            #expect(errorResponse.error.code == "accountHasBeenMoved", "Error code should be equal 'accountHasBeenMoved'.")
            
            let follow = try await application.getFollow(sourceId: user1.requireID(), targetId: user2.requireID())
            #expect(follow == nil, "Follow must not be added to local datbase for moved account.")
        }
        
        @Test
        func `Follow requests approve should fail for unauthorized user`() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "hermanerst", generateKeys: true)
            let user2 = try await application.createUser(userName: "robinerst", generateKeys: true)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/users/\(user2.userName)/follow",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
