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
    
    @Suite("FollowRequests (POST /follow-requests/:id/approve)", .serialized, .tags(.followRequests))
    struct FollowRequestsApproveActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Follow request approve should finish successfully for authorized user")
        func followRequestApproveShouldFinishSuccessfullyForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictorfubo", generateKeys: true)
            let user2 = try await application.createUser(userName: "marianfubo", generateKeys: true)
            
            _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
            
            // Act.
            let relationship = try application.getResponse(
                as: .user(userName: "wictorfubo", password: "p@ssword"),
                to: "/follow-requests/\(user2.stringId() ?? "")/approve",
                method: .POST,
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.followedBy, "User 2 is following now User 1.")
        }
        
        @Test("Follow requests approve should fail for unauthorized user")
        func followRequestsApproveShouldFailForUnauthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "hermanfubo", generateKeys: true)
            let user2 = try await application.createUser(userName: "robinfubo", generateKeys: true)
            
            _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
            
            // Act.
            let response = try application.sendRequest(
                to: "/follow-requests/\(user2.stringId() ?? "")/approve",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
