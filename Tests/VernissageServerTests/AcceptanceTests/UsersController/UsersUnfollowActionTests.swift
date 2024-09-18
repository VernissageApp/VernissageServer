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
    
    @Suite("POST /:username/unfollow", .serialized, .tags(.users))
    struct UsersUnfollowActionTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Unfollow should finish successfully for authorized user")
        func unfollowShouldFinishSuccessfullyForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictordera", generateKeys: true)
            let user2 = try await application.createUser(userName: "mariandera", generateKeys: true)
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            // Act.
            let relationship = try application.getResponse(
                as: .user(userName: "wictordera", password: "p@ssword"),
                to: "/users/\(user2.userName)/unfollow",
                method: .POST,
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.following == false, "User 1 is following now User 2.")
        }
        
        @Test("Unfollow requests approve should fail for unauthorized user")
        func unfollowRequestsApproveShouldFailForUnauthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "hermandera", generateKeys: true)
            let user2 = try await application.createUser(userName: "robinedera", generateKeys: true)
            
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            // Act.
            let response = try application.sendRequest(
                to: "/users/\(user2.userName)/unfollow",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
