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

@Suite("ActivityPubService (Create)", .serialized)
struct ActivityPubServiceCreateTests {
    let externalImageUrl = "https://joinvernissage.org/images/001.png?v=tmnnh3o0"

    var application: Application!

    init() async throws {
        self.application = try await ApplicationManager.shared.application()
    }

    @Test
    func `Followers create delivered to user inbox should stay followers-only`() async throws {
        // Arrange.
        let activityPubService = ActivityPubService()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubUserInboxJob"))

        let sourceUser = try await application.createUser(userName: "remotefollowerscreate", isLocal: false)

        let recipientUser = try await application.createUser(userName: "followersrecipient")
        _ = try await application.createUser(userName: "followersnonrecipient")

        _ = try await application.createFollow(sourceId: recipientUser.requireID(), targetId: sourceUser.requireID(), approved: true)

        let attachment = try await application.createAttachment(user: recipientUser)
        defer {
            application.clearFiles(attachments: [attachment])
        }
        let parentStatus = try await application.createStatus(user: recipientUser,
                                                              note: "Parent for followers-only comment",
                                                              attachmentIds: [attachment.stringId()!])

        let noteId = "https://remote.example/statuses/followers-only-create-1"
        let noteDto = NoteDto(id: noteId,
                              summary: nil,
                              inReplyTo: parentStatus.activityPubId,
                              published: Date().toISO8601String(),
                              updated: nil,
                              url: noteId,
                              attributedTo: sourceUser.activityPubProfile,
                              to: .single(ActorDto(id: "\(sourceUser.activityPubProfile)/followers")),
                              cc: nil,
                              sensitive: false,
                              atomUri: nil,
                              inReplyToAtomUri: nil,
                              conversation: nil,
                              content: "Followers only create.",
                              attachment: nil,
                              tag: nil)

        let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                   type: .create,
                                   id: "\(noteId)/activity",
                                   actor: .single(ActorDto(id: sourceUser.activityPubProfile)),
                                   to: noteDto.to,
                                   cc: noteDto.cc,
                                   object: .single(ObjectDto(id: noteDto.id, type: .note, object: noteDto)),
                                   summary: nil,
                                   signature: nil,
                                   published: noteDto.published)

        let request = ActivityPubRequestDto(activity: activity,
                                            headers: [:],
                                            bodyHash: nil,
                                            bodyValue: "{}",
                                            httpMethod: .post,
                                            httpPath: .userInbox(recipientUser.userName),
                                            receivedAt: Date.now)

        // Act.
        try await activityPubService.create(activityPubRequest: request, on: queueContext.executionContext)

        // Assert.
        let status = try await Status.query(on: application.db)
            .filter(\.$activityPubId == noteId)
            .first()

        let createdStatus = try #require(status)
        #expect(createdStatus.visibility == .followers, "Status visibility should be followers.")
        #expect(createdStatus.$replyToStatus.id == parentStatus.id, "Comment should be linked to parent status.")
    }

    @Test
    func `Mentioned create delivered to user inbox should be accepted even if actor is not followed`() async throws {
        // Arrange.
        let activityPubService = ActivityPubService()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubUserInboxJob"))

        let sourceUser = try await application.createUser(userName: "remotementionedcreate", isLocal: false)

        let mentionedRecipient = try await application.createUser(userName: "mentionedrecipient")
        let attachment = try await application.createAttachment(user: mentionedRecipient)
        defer {
            application.clearFiles(attachments: [attachment])
        }
        let parentStatus = try await application.createStatus(user: mentionedRecipient,
                                                              note: "Parent for mentioned-only comment",
                                                              attachmentIds: [attachment.stringId()!])

        let noteId = "https://remote.example/statuses/mentioned-only-create-1"
        let noteDto = NoteDto(id: noteId,
                              summary: nil,
                              inReplyTo: parentStatus.activityPubId,
                              published: Date().toISO8601String(),
                              updated: nil,
                              url: noteId,
                              attributedTo: sourceUser.activityPubProfile,
                              to: .single(ActorDto(id: mentionedRecipient.activityPubProfile)),
                              cc: nil,
                              sensitive: false,
                              atomUri: nil,
                              inReplyToAtomUri: nil,
                              conversation: nil,
                              content: "Direct mentioned create.",
                              attachment: nil,
                              tag: nil)

        let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                   type: .create,
                                   id: "\(noteId)/activity",
                                   actor: .single(ActorDto(id: sourceUser.activityPubProfile)),
                                   to: noteDto.to,
                                   cc: noteDto.cc,
                                   object: .single(ObjectDto(id: noteDto.id, type: .note, object: noteDto)),
                                   summary: nil,
                                   signature: nil,
                                   published: noteDto.published)

        let request = ActivityPubRequestDto(activity: activity,
                                            headers: [:],
                                            bodyHash: nil,
                                            bodyValue: "{}",
                                            httpMethod: .post,
                                            httpPath: .userInbox(mentionedRecipient.userName),
                                            receivedAt: Date.now)

        // Act.
        try await activityPubService.create(activityPubRequest: request, on: queueContext.executionContext)

        // Assert.
        let status = try await Status.query(on: application.db)
            .filter(\.$activityPubId == noteId)
            .first()

        let createdStatus = try #require(status)
        #expect(createdStatus.visibility == .mentioned, "Status visibility should be mentioned.")
        #expect(createdStatus.$replyToStatus.id == parentStatus.id, "Comment should be linked to parent status.")
    }

    @Test
    func `Mentioned create delivered to user inbox should be rejected when recipient is not in addressing`() async throws {
        // Arrange.
        let activityPubService = ActivityPubService()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubUserInboxJob"))

        let sourceUser = try await application.createUser(userName: "remotementionedwrongrecipient", isLocal: false)
        let inboxRecipient = try await application.createUser(userName: "mentionedwrongrecipient")
        let explicitlyAddressedRecipient = try await application.createUser(userName: "mentionedexplicitrecipient")

        let attachment = try await application.createAttachment(user: inboxRecipient)
        defer {
            application.clearFiles(attachments: [attachment])
        }
        let parentStatus = try await application.createStatus(user: inboxRecipient,
                                                              note: "Parent for mentioned mismatch comment",
                                                              attachmentIds: [attachment.stringId()!])

        let noteId = "https://remote.example/statuses/mentioned-wrong-recipient-create-1"
        let noteDto = NoteDto(id: noteId,
                              summary: nil,
                              inReplyTo: parentStatus.activityPubId,
                              published: Date().toISO8601String(),
                              updated: nil,
                              url: noteId,
                              attributedTo: sourceUser.activityPubProfile,
                              to: .single(ActorDto(id: explicitlyAddressedRecipient.activityPubProfile)),
                              cc: nil,
                              sensitive: false,
                              atomUri: nil,
                              inReplyToAtomUri: nil,
                              conversation: nil,
                              content: "Mentioned create delivered to wrong inbox recipient.",
                              attachment: nil,
                              tag: nil)

        let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                   type: .create,
                                   id: "\(noteId)/activity",
                                   actor: .single(ActorDto(id: sourceUser.activityPubProfile)),
                                   to: noteDto.to,
                                   cc: noteDto.cc,
                                   object: .single(ObjectDto(id: noteDto.id, type: .note, object: noteDto)),
                                   summary: nil,
                                   signature: nil,
                                   published: noteDto.published)

        let request = ActivityPubRequestDto(activity: activity,
                                            headers: [:],
                                            bodyHash: nil,
                                            bodyValue: "{}",
                                            httpMethod: .post,
                                            httpPath: .userInbox(inboxRecipient.userName),
                                            receivedAt: Date.now)

        // Act.
        try await activityPubService.create(activityPubRequest: request, on: queueContext.executionContext)

        // Assert.
        let status = try await Status.query(on: application.db)
            .filter(\.$activityPubId == noteId)
            .first()

        #expect(status == nil, "Status should not be created when user inbox recipient is not addressed.")
    }

    @Test
    func `Public create delivered to user inbox should be added to followers timeline and public timeline`() async throws {
        // Arrange.
        let activityPubService = ActivityPubService()
        let queueContext = application.getQueueContext(queueName: QueueName(string: "ActivityPubUserInboxJob"))
        let timelineService = application.services.timelineService

        let sourceUser = try await application.createUser(userName: "remotepubliccreate", isLocal: false)
        let followerRecipient = try await application.createUser(userName: "publicfollowerrecipient")
        let nonFollowerRecipient = try await application.createUser(userName: "publicnonfollowerrecipient")

        _ = try await application.createFollow(sourceId: followerRecipient.requireID(), targetId: sourceUser.requireID(), approved: true)

        let noteId = "https://remote.example/statuses/public-create-1"
        let noteDto = NoteDto(id: noteId,
                              summary: nil,
                              inReplyTo: nil,
                              published: Date().toISO8601String(),
                              updated: nil,
                              url: noteId,
                              attributedTo: sourceUser.activityPubProfile,
                              to: .single(ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")),
                              cc: .single(ActorDto(id: "\(sourceUser.activityPubProfile)/followers")),
                              sensitive: false,
                              atomUri: nil,
                              inReplyToAtomUri: nil,
                              conversation: nil,
                              content: "Public create delivered to user inbox.",
                              attachment: [
                                MediaAttachmentDto(mediaType: "image/png",
                                                   url: externalImageUrl,
                                                   name: "Public image",
                                                   blurhash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
                                                   width: 1706,
                                                   height: 882,
                                                   hdrImageUrl: nil,
                                                   exif: nil,
                                                   exifData: nil,
                                                   location: nil)
                              ],
                              tag: nil)

        let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                                   type: .create,
                                   id: "\(noteId)/activity",
                                   actor: .single(ActorDto(id: sourceUser.activityPubProfile)),
                                   to: noteDto.to,
                                   cc: noteDto.cc,
                                   object: .single(ObjectDto(id: noteDto.id, type: .note, object: noteDto)),
                                   summary: nil,
                                   signature: nil,
                                   published: noteDto.published)

        let request = ActivityPubRequestDto(activity: activity,
                                            headers: [:],
                                            bodyHash: nil,
                                            bodyValue: "{}",
                                            httpMethod: .post,
                                            httpPath: .userInbox(followerRecipient.userName),
                                            receivedAt: Date.now)

        // Act.
        try await activityPubService.create(activityPubRequest: request, on: queueContext.executionContext)

        // Assert.
        let status = try await Status.query(on: application.db)
            .filter(\.$activityPubId == noteId)
            .first()

        let createdStatus = try #require(status)
        let createdStatusId = try createdStatus.requireID()
        #expect(createdStatus.visibility == .public, "Status visibility should be public.")

        let followerUserStatus = try await UserStatus.query(on: application.db)
            .filter(\.$status.$id == createdStatusId)
            .filter(\.$user.$id == followerRecipient.requireID())
            .first()

        #expect(followerUserStatus != nil, "Public status should be added to follower timeline.")

        let nonFollowerUserStatus = try await UserStatus.query(on: application.db)
            .filter(\.$status.$id == createdStatusId)
            .filter(\.$user.$id == nonFollowerRecipient.requireID())
            .first()

        #expect(nonFollowerUserStatus == nil, "Public status should not be added to non-follower home timeline.")

        let publicStatuses = try await timelineService.public(linkableParams: LinkableParams(maxId: nil, minId: nil, sinceId: nil, limit: 40),
                                                              onlyLocal: false,
                                                              forUserId: nil,
                                                              on: queueContext.executionContext)
        #expect(publicStatuses.contains(where: { $0.id == createdStatus.id }), "Public status should be visible in public timeline.")

        let attachments = try await Attachment.query(on: application.db)
            .filter(\.$status.$id == createdStatusId)
            .with(\.$originalFile)
            .with(\.$smallFile)
            .all()
        application.clearFiles(attachments: attachments)
    }
}
