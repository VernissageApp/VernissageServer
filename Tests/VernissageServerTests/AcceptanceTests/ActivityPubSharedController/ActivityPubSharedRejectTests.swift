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

extension ActivityPubSharedControllerTests {
    
    @Suite("POST /inbox [Reject]", .serialized, .tags(.shared))
    struct ActivityPubSharedRejectTests {
        var application: Application!
        
        init() async throws {
            try await ApplicationManager.shared.initApplication()
            self.application = await ApplicationManager.shared.application
        }
        
        @Test("Accept should success when all correct data has been applied")
        func acceptShouldSuccessWhenAllCorrectDataHasBeenApplied() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "vikihorn", generateKeys: true)
            let user2 = try await application.createUser(userName: "rickhorn", generateKeys: true)
            _ = try await application.createFollow(sourceId: user1.requireID(), targetId: user2.requireID(), approved: false)
            
            let rejectTarget = ActivityPub.Users.reject(user1.activityPubProfile,
                                                        user2.activityPubProfile,
                                                        user2.privateKey!,
                                                        "/shared/inbox",
                                                        Constants.userAgent,
                                                        "localhost",
                                                        123,
                                                        "https://localhost/follow/212")
            
            // Act.
            _ = try application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: rejectTarget.headers?.getHTTPHeaders() ?? .init(),
                body: rejectTarget.httpBody!)
            
            // Assert.
            let follow = try await application.getFollow(sourceId: user1.requireID(), targetId: user2.requireID())
            #expect(follow == nil, "Follow must be deleted from local datbase.")
        }
    }
}
