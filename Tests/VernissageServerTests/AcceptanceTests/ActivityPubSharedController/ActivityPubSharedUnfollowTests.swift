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
    
    @Suite("ActivityPubShared (POST /shared/inbox [Unfollow])", .serialized, .tags(.shared))
    struct ActivityPubSharedUnfollowTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test("Unfollow should success when all correct data has been applied")
        func unfollowShouldSuccessWhenAllCorrectDataHasBeenApplied() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "vikibugs", generateKeys: true)
            let user2 = try await application.createUser(userName: "rickbugs", generateKeys: true)
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: true)
            
            let followTarget = ActivityPub.Users.unfollow(user1.activityPubProfile,
                                                          user2.activityPubProfile,
                                                          user1.privateKey!,
                                                          "/shared/inbox",
                                                          Constants.userAgent,
                                                          "localhost",
                                                          123)
            
            // Act.
            _ = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: followTarget.headers?.getHTTPHeaders() ?? .init(),
                body: followTarget.httpBody!)
            
            // Assert.
            let follow = try await application.getFollow(sourceId: user1.requireID(), targetId: user2.requireID())
            #expect(follow == nil, "Follow must be deleted from local datbase")
        }
    }
}
