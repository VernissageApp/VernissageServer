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

@Suite("ActivityPubIncomingService (Announce)", .serialized)
struct ActivityPubIncomingServiceAnnounceTests {

    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Announce from suppressed user should not create reblog`() async throws {
        // Arrange.
        let activityPubIncomingService = ActivityPubIncomingService()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))

        let statusOwner = try await application.createUser(userName: "announceownersuppressedactor")
        let announcer = try await application.createUser(userName: "announcersuppressed", isLocal: false, isSuppressed: true)

        let attachment = try await application.createAttachment(user: statusOwner)
        defer {
            application.clearFiles(attachments: [attachment])
        }
        let status = try await application.createStatus(user: statusOwner,
                                                        note: "Status announced by suppressed actor",
                                                        attachmentIds: [attachment.stringId()!])

        let request = self.createAnnounceRequest(activityId: "https://remote.example/activities/announce-suppressed-actor-1",
                                                 actorActivityPubId: announcer.activityPubProfile,
                                                 object: ObjectDto(id: status.activityPubId))

        // Act.
        try await activityPubIncomingService.announce(activityPubRequest: request, on: queueContext.executionContext)

        // Assert.
        let reblog = try await Status.query(on: application.db)
            .filter(\.$user.$id == announcer.requireID())
            .filter(\.$reblog.$id == status.requireID())
            .first()

        #expect(reblog == nil, "Reblog from suppressed user should not be created.")

        let refreshedStatus = try await Status.query(on: application.db)
            .filter(\.$id == status.requireID())
            .first()

        #expect(refreshedStatus?.reblogsCount == 0, "Reblogs counter should not be incremented.")
    }

    @Test
    func `Announce of status owned by suppressed user should not download status`() async throws {
        // Arrange.
        let activityPubIncomingService = ActivityPubIncomingService()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubSharedInboxJob"))

        let statusOwner = try await application.createUser(userName: "suppressedannounceowner", isLocal: false, isSuppressed: true)
        let announcer = try await application.createUser(userName: "announcerofsuppressedstatus", isLocal: false)
        let localFollower = try await application.createUser(userName: "followerofannouncer")
        _ = try await application.createFollow(sourceId: localFollower.requireID(), targetId: announcer.requireID(), approved: true)

        let noteId = "https://remote.example/statuses/announce-suppressed-owner-1"
        let noteDto = NoteDto(id: noteId,
                              summary: nil,
                              inReplyTo: nil,
                              published: Date().toISO8601String(),
                              updated: nil,
                              url: noteId,
                              attributedTo: statusOwner.activityPubProfile,
                              to: .single(ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")),
                              cc: .single(ActorDto(id: "\(statusOwner.activityPubProfile)/followers")),
                              sensitive: false,
                              atomUri: nil,
                              inReplyToAtomUri: nil,
                              conversation: nil,
                              content: "Status owned by suppressed user",
                              attachment: [
                                MediaAttachmentDto(mediaType: "image/png",
                                                   url: "https://remote.example/images/suppressed-owner.png",
                                                   name: "Suppressed image",
                                                   blurhash: nil,
                                                   width: 1024,
                                                   height: 768,
                                                   hdrImageUrl: nil,
                                                   exif: nil,
                                                   exifData: nil,
                                                   location: nil)
                              ],
                              tag: nil)

        let request = self.createAnnounceRequest(activityId: "https://remote.example/activities/announce-suppressed-owner-1",
                                                 actorActivityPubId: announcer.activityPubProfile,
                                                 object: ObjectDto(id: noteDto.id, type: .note, object: noteDto))

        // Act.
        try await activityPubIncomingService.announce(activityPubRequest: request, on: queueContext.executionContext)

        // Assert.
        let status = try await Status.query(on: application.db)
            .filter(\.$activityPubId == noteId)
            .first()

        #expect(status == nil, "Status owned by suppressed user should not be downloaded.")
    }

    @Test
    func `Duplicate announce delivered to inboxes should create single reblog`() async throws {
        // Arrange.
        let activityPubIncomingService = ActivityPubIncomingService()
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
        try await activityPubIncomingService.announce(activityPubRequest: sharedInboxRequest, on: queueContext.executionContext)
        try await activityPubIncomingService.announce(activityPubRequest: userInboxRequest, on: queueContext.executionContext)

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

    private func createAnnounceRequest(activityId: String,
                                       actorActivityPubId: String,
                                       object: ObjectDto) -> ActivityPubRequestDto {
        let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                   type: .announce,
                                   id: activityId,
                                   actor: .single(ActorDto(id: actorActivityPubId)),
                                   to: nil,
                                   cc: nil,
                                   object: .single(object),
                                   summary: nil,
                                   signature: nil,
                                   published: Date().toISO8601String())

        return ActivityPubRequestDto(activity: activity,
                                     headers: [:],
                                     bodyHash: nil,
                                     bodyValue: "{}",
                                     httpMethod: .post,
                                     httpPath: .sharedInbox,
                                     receivedAt: Date.now)
    }
}
