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
    
    @Suite("FollowRequests (POST /follow-requests/:id/reject)", .serialized, .tags(.followRequests))
    struct FollowRequestsRejectActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Follow request reject should finish successfully for authorized user")
        func followRequestRejectShouldFinishSuccessfullyForAuthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "wictormoro", generateKeys: true)
            let user2 = try await application.createUser(userName: "marianmoro", generateKeys: true)
            
            _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
            
            // Act.
            let relationship = try application.getResponse(
                as: .user(userName: "wictormoro", password: "p@ssword"),
                to: "/follow-requests/\(user2.stringId() ?? "")/reject",
                method: .POST,
                decodeTo: RelationshipDto.self
            )
            
            // Assert.
            #expect(relationship.followedBy == false, "User 2 is not following User 1.")
        }
        
        @Test("Follow requests reject should fail for unauthorized user")
        func followRequestsRejectShouldFailForUnauthorizedUser() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "hermanmoro", generateKeys: true)
            let user2 = try await application.createUser(userName: "robinmoro", generateKeys: true)
            
            _ = try await application.createFollow(sourceId: user2.requireID(), targetId: user1.requireID(), approved: false)
            
            // Act.
            let response = try application.sendRequest(
                to: "/follow-requests/\(user2.stringId() ?? "")/reject",
                method: .POST
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }
    }
}
