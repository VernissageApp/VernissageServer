//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing

extension ControllersTests {
    
    @Suite("ActivityPubShared (POST /shared/inbox [Move])", .serialized, .tags(.shared))
    struct ActivityPubSharedMoveTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Move should migrate local followers when alias is valid`() async throws {
            // Arrange.
            let sourceUser = try await application.createUser(userName: "sharedmovesource", generateKeys: true)
            let targetUser = try await application.createUser(userName: "sharedmovetarget", generateKeys: true)
            let localFollower = try await application.createUser(userName: "sharedfollower", generateKeys: true)
            
            _ = try await application.createUserAlias(userId: targetUser.requireID(),
                                                      alias: "sharedmovesource@localhost:8080",
                                                      activityPubProfile: sourceUser.activityPubProfile)
            sourceUser.$movedTo.id = try targetUser.requireID()
            try await sourceUser.save(on: application.db)
            
            _ = try await application.createFollow(sourceId: localFollower.requireID(),
                                                   targetId: sourceUser.requireID(),
                                                   approved: true)
            
            let moveTarget = ActivityPub.Users.move(sourceUser.activityPubProfile,
                                                    targetUser.activityPubProfile,
                                                    sourceUser.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost",
                                                    444)
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: moveTarget.headers?.getHTTPHeaders() ?? .init(),
                body: moveTarget.httpBody!
            )
            
            // Assert.
            #expect(response.status == .ok)
            
            let oldFollow = try await application.getFollow(sourceId: localFollower.requireID(), targetId: sourceUser.requireID())
            #expect(oldFollow == nil)
            
            let newFollow = try await application.getFollow(sourceId: localFollower.requireID(), targetId: targetUser.requireID())
            #expect(newFollow != nil)
            
            let refreshedSource = try await application.getUser(id: sourceUser.requireID())
            let movedToProfile = try await refreshedSource?.$movedTo.get(on: application.db)?.activityPubProfile
            #expect(movedToProfile == targetUser.activityPubProfile)
        }
        
        @Test
        func `Move should be ignored when target is not alias of source`() async throws {
            // Arrange.
            let sourceUser = try await application.createUser(userName: "sharedmovesource2", generateKeys: true)
            let targetUser = try await application.createUser(userName: "sharedmovetarget2", generateKeys: true)
            let localFollower = try await application.createUser(userName: "sharedfollower2", generateKeys: true)
            
            _ = try await application.createFollow(sourceId: localFollower.requireID(),
                                                   targetId: sourceUser.requireID(),
                                                   approved: true)
            
            let moveTarget = ActivityPub.Users.move(sourceUser.activityPubProfile,
                                                    targetUser.activityPubProfile,
                                                    sourceUser.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost",
                                                    445)
            
            // Act.
            _ = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: moveTarget.headers?.getHTTPHeaders() ?? .init(),
                body: moveTarget.httpBody!
            )
            
            // Assert.
            let oldFollow = try await application.getFollow(sourceId: localFollower.requireID(), targetId: sourceUser.requireID())
            #expect(oldFollow != nil)
            
            let newFollow = try await application.getFollow(sourceId: localFollower.requireID(), targetId: targetUser.requireID())
            #expect(newFollow == nil)
            
            let refreshedSource = try await application.getUser(id: sourceUser.requireID())
            let movedToProfile = try await refreshedSource?.$movedTo.get(on: application.db)?.activityPubProfile
            #expect(movedToProfile == nil)
        }

        @Test
        func `Move should be ignored when source movedTo does not point to target`() async throws {
            // Arrange.
            let sourceUser = try await application.createUser(userName: "sharedmovesource3", generateKeys: true)
            let targetUser = try await application.createUser(userName: "sharedmovetarget3", generateKeys: true)
            let differentTargetUser = try await application.createUser(userName: "sharedmovedifferent3", generateKeys: true)
            let localFollower = try await application.createUser(userName: "sharedfollower3", generateKeys: true)

            _ = try await application.createUserAlias(userId: targetUser.requireID(),
                                                      alias: "sharedmovesource3@localhost:8080",
                                                      activityPubProfile: sourceUser.activityPubProfile)
            sourceUser.$movedTo.id = try differentTargetUser.requireID()
            try await sourceUser.save(on: application.db)

            _ = try await application.createFollow(sourceId: localFollower.requireID(),
                                                   targetId: sourceUser.requireID(),
                                                   approved: true)

            let moveTarget = ActivityPub.Users.move(sourceUser.activityPubProfile,
                                                    targetUser.activityPubProfile,
                                                    sourceUser.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost",
                                                    446)

            // Act.
            _ = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: moveTarget.headers?.getHTTPHeaders() ?? .init(),
                body: moveTarget.httpBody!
            )

            // Assert.
            let oldFollow = try await application.getFollow(sourceId: localFollower.requireID(), targetId: sourceUser.requireID())
            #expect(oldFollow != nil)

            let newFollow = try await application.getFollow(sourceId: localFollower.requireID(), targetId: targetUser.requireID())
            #expect(newFollow == nil)

            let refreshedSource = try await application.getUser(id: sourceUser.requireID())
            let movedToProfile = try await refreshedSource?.$movedTo.get(on: application.db)?.activityPubProfile
            #expect(movedToProfile == differentTargetUser.activityPubProfile)
        }
    }
}
