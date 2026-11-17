//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Testing
import Queues
import ActivityPubKit
import Fluent

@Suite("ActivityPubIncomingService (Like)", .serialized)
struct ActivityPubIncomingServiceLikeTests {
    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Like through boost should target original status`() async throws {
        // Arrange.
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let owner = try await application.createUser(userName: "bo" + suffix)
        let booster = try await application.createUser(userName: "bb" + suffix)
        let original = try await application.createStatus(user: owner, note: "Original photo")
        let boost = try await application.createStatus(user: booster, note: nil, reblogId: original.requireID())
        let remote = try await application.createUser(userName: "br" + suffix, isLocal: false)
        remote.activityPubProfile = "https://remote.example/actors/" + remote.userName
        remote.activityPubProfileNormalized = remote.activityPubProfile.uppercased()
        try await remote.save(on: application.db)
        let activityPubIncomingService = ActivityPubIncomingService()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let requestActivity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                          type: .like,
                                          id: remote.activityPubProfile + "/activities/" + UUID().uuidString,
                                          actor: .single(ActorDto(id: remote.activityPubProfile)),
                                          object: .single(ObjectDto(id: boost.activityPubId)),
                                          summary: nil,
                                          signature: nil)
        let request = ActivityPubRequestDto(activity: requestActivity, headers: [:], bodyHash: nil, bodyValue: "{}",
                                            httpMethod: .post, httpPath: .sharedInbox, receivedAt: Date())

        // Act.
        try await activityPubIncomingService.like(activityPubRequest: request, on: queueContext.executionContext)

        // Assert.
        let favourite = try #require(try await StatusFavourite.query(on: application.db)
            .filter(\.$user.$id == remote.requireID()).first())
        #expect(favourite.$status.id == original.id)
        #expect(try await application.getStatus(id: original.requireID())?.favouritesCount == 1)
        #expect(try await application.getStatus(id: boost.requireID())?.favouritesCount == 0)
        #expect(try await application.getNotification(
            type: .favourite, to: owner.requireID(), by: remote.requireID(), statusId: original.requireID()) != nil)
        #expect(try await application.getNotification(
            type: .favourite, to: booster.requireID(), by: remote.requireID(), statusId: boost.requireID()) == nil)
    }

}
