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
    
    @Suite("POST /:username/follow", .serialized, .tags(.users))
    struct UsersFollowActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Follow should finish successfully for authorized user")
        func followShouldFinishSuccessfullyForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictorerst", generateKeys: true)
            let user2 = try await application.createUser(userName: "marianerst", generateKeys: true)
            
            // Act.
            let relationship = try application.getResponse(
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
        
        @Test("Follow should be requested for manual approval")
        func followShouldBeRequestedForManualApproval() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "annaerst", generateKeys: true)
            let user2 = try await application.createUser(userName: "karinerst", manuallyApprovesFollowers: true, generateKeys: true)
            
            // Act.
            let relationship = try application.getResponse(
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
        
        @Test("Follow requests approve should fail for unauthorized user")
        func followRequestsApproveShouldFailForUnauthorizedUser() async throws {
            // Arrange.
            _ = try await application.createUser(userName: "hermanerst", generateKeys: true)
            let user2 = try await application.createUser(userName: "robinerst", generateKeys: true)
            
            // Act.
            let response = try application.sendRequest(
                to: "/users/\(user2.userName)/follow",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
