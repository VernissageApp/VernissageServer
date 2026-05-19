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

@Suite("ActivityPubService (Announce)", .serialized)
struct ActivityPubServiceAnnounceTests {

    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Duplicate announce delivered to inboxes should create single reblog`() async throws {
        // Arrange.
        let activityPubService = ActivityPubService()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))

        let statusOwner = try await application.createUser(userName: "announceownerlocal")
        let announcer = try await application.createUser(userName: "announcerremote", isLocal: false)

        let attachment = try await application.createAttachment(user: statusOwner)
        defer {
            application.clearFiles(attachments: [attachment])
        }
        let status = try await application.createStatus(user: statusOwner,
                                                        note: "Status to be announced once",
                                                        attachmentIds: [attachment.stringId()!])

        let activityId = "https://remote.example/activities/announce-duplicate-1"
        let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                   type: .announce,
                                   id: activityId,
                                   actor: .single(ActorDto(id: announcer.activityPubProfile)),
                                   to: nil,
                                   cc: nil,
                                   object: .single(ObjectDto(id: status.activityPubId)),
                                   summary: nil,
                                   signature: nil,
                                   published: Date().toISO8601String())

        let sharedInboxRequest = ActivityPubRequestDto(activity: activity,
                                                       headers: [:],
                                                       bodyHash: nil,
                                                       bodyValue: "{}",
                                                       httpMethod: .post,
                                                       httpPath: .sharedInbox,
                                                       receivedAt: Date.now)

        let userInboxRequest = ActivityPubRequestDto(activity: activity,
                                                     headers: [:],
                                                     bodyHash: nil,
                                                     bodyValue: "{}",
                                                     httpMethod: .post,
                                                     httpPath: .userInbox(statusOwner.userName),
                                                     receivedAt: Date.now)

        // Act.
        try await activityPubService.announce(activityPubRequest: sharedInboxRequest, on: queueContext.executionContext)
        try await activityPubService.announce(activityPubRequest: userInboxRequest, on: queueContext.executionContext)

        // Assert.
        let reblogs = try await Status.query(on: application.db)
            .filter(\.$user.$id == announcer.requireID())
            .filter(\.$reblog.$id == status.requireID())
            .all()

        #expect(reblogs.count == 1, "Only one reblog should be created for duplicated announce delivery.")

        let refreshedStatus = try await Status.query(on: application.db)
            .filter(\.$id == status.requireID())
            .first()

        #expect(refreshedStatus?.reblogsCount == 1, "Reblogs counter should be incremented only once.")
    }
}
