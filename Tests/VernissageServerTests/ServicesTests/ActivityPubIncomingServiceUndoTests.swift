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

@Suite("ActivityPubIncomingService (Undo)", .serialized)
struct ActivityPubIncomingServiceUndoTests {
    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Undo Announce through boost should remove boost of original status`() async throws {
        // Arrange.
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let owner = try await application.createUser(userName: "bo" + suffix)
        let booster = try await application.createUser(userName: "bb" + suffix)
        let original = try await application.createStatus(user: owner, note: "Original photo")
        let boost = try await application.createStatus(user: booster, note: nil, reblogId: original.requireID())
        let attachment = try await application.createAttachment(user: owner)
        defer {
            application.clearFiles(attachments: [attachment])
        }
        attachment.$status.id = original.id
        try await attachment.save(on: application.db)
        let remote = try await application.createUser(userName: "br" + suffix, isLocal: false)
        remote.activityPubProfile = "https://remote.example/actors/" + remote.userName
        remote.activityPubProfileNormalized = remote.activityPubProfile.uppercased()
        try await remote.save(on: application.db)
        let activityPubIncomingService = ActivityPubIncomingService()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))
        let announceRequestActivity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                          type: .announce,
                                          id: remote.activityPubProfile + "/activities/" + UUID().uuidString,
                                          actor: .single(ActorDto(id: remote.activityPubProfile)),
                                          object: .single(ObjectDto(id: original.activityPubId)),
                                          summary: nil,
                                          signature: nil)
        let announceRequest = ActivityPubRequestDto(activity: announceRequestActivity, headers: [:], bodyHash: nil, bodyValue: "{}",
                                            httpMethod: .post, httpPath: .sharedInbox, receivedAt: Date())
        try await activityPubIncomingService.announce(activityPubRequest: announceRequest, on: queueContext.executionContext)
        let saved = try #require(try await Status.query(on: application.db)
            .filter(\.$user.$id == remote.requireID()).filter(\.$reblog.$id != nil).first())
        let announce = AnnouceDto(id: announceRequest.activity.id, published: nil,
                                 actor: .single(ActorDto(id: remote.activityPubProfile)), to: nil, cc: nil,
                                 object: .single(ObjectDto(id: boost.activityPubId)))
        let requestActivity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                          type: .undo,
                                          id: remote.activityPubProfile + "/activities/" + UUID().uuidString,
                                          actor: .single(ActorDto(id: remote.activityPubProfile)),
                                          object: .single(ObjectDto(id: announce.id, type: .announce, object: announce)),
                                          summary: nil,
                                          signature: nil)
        let request = ActivityPubRequestDto(activity: requestActivity, headers: [:], bodyHash: nil, bodyValue: "{}",
                                            httpMethod: .post, httpPath: .sharedInbox, receivedAt: Date())

        // Act.
        try await activityPubIncomingService.undo(activityPubRequest: request, on: queueContext.executionContext)

        // Assert.
        #expect(try await application.getStatus(id: saved.requireID()) == nil)
        #expect(try await application.getStatus(id: original.requireID())?.reblogsCount == 1)
        #expect(try await application.getStatus(id: boost.requireID()) != nil)
    }

    @Test
    func `Undo Like through boost should remove favourite from original status`() async throws {
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
        let likeRequestActivity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                          type: .like,
                                          id: remote.activityPubProfile + "/activities/" + UUID().uuidString,
                                          actor: .single(ActorDto(id: remote.activityPubProfile)),
                                          object: .single(ObjectDto(id: original.activityPubId)),
                                          summary: nil,
                                          signature: nil)
        let likeRequest = ActivityPubRequestDto(activity: likeRequestActivity, headers: [:], bodyHash: nil, bodyValue: "{}",
                                            httpMethod: .post, httpPath: .sharedInbox, receivedAt: Date())
        try await activityPubIncomingService.like(activityPubRequest: likeRequest, on: queueContext.executionContext)
        let favourite = try #require(try await StatusFavourite.query(on: application.db)
            .filter(\.$user.$id == remote.requireID()).first())
        let like = LikeDto(id: likeRequest.activity.id, actor: .single(ActorDto(id: remote.activityPubProfile)),
                           to: nil, cc: nil, object: .single(ObjectDto(id: boost.activityPubId)))
        let requestActivity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                          type: .undo,
                                          id: remote.activityPubProfile + "/activities/" + UUID().uuidString,
                                          actor: .single(ActorDto(id: remote.activityPubProfile)),
                                          object: .single(ObjectDto(id: like.id, type: .like, object: like)),
                                          summary: nil,
                                          signature: nil)
        let request = ActivityPubRequestDto(activity: requestActivity, headers: [:], bodyHash: nil, bodyValue: "{}",
                                            httpMethod: .post, httpPath: .sharedInbox, receivedAt: Date())

        // Act.
        try await activityPubIncomingService.undo(activityPubRequest: request, on: queueContext.executionContext)

        // Assert.
        #expect(try await StatusFavourite.find(favourite.requireID(), on: application.db) == nil)
        #expect(try await application.getStatus(id: original.requireID())?.favouritesCount == 0)
        #expect(try await application.getStatus(id: boost.requireID())?.favouritesCount == 0)
    }

}
