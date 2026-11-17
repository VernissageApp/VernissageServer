//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Fluent
import Testing
import Vapor

extension ControllersTests {
    @Suite("ActivityPubShared (POST /shared/inbox [UpdateStatus])", .serialized, .tags(.shared))
    struct ActivityPubSharedUpdateStatusTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test(arguments: [false, true])
        func `Private Update preserves audience read state and inbox order while refreshing the preview`(personalInbox: Bool) async throws {
            // Arrange.
            let remote = try await application.createRemoteDirectMessageUser()
            let local = try await application.createDirectMessageUser()
            let outsider = try await application.createDirectMessageUser()
            let note = privateActivityPubNote(sender: remote, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(note, sender: remote)
            let original = try #require(try await application.services.statusesService.get(activityPubId: note.id, on: application.db))
            let statusId = try original.requireID()
            let conversationId = try #require(original.$directConversation.id)
            try await application.services.directMessagesService.markRead(conversationId: conversationId,
                statusIds: [String(statusId)], userId: local.requireID(), on: executionContext)
            let inboxBefore = try #require(try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == conversationId)
                .first())
            let recipientBefore = try #require(try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == statusId)
                .first())
            let notificationCount = try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == statusId)
                .count()
            let update = edited(note, content: "<p>Edited &amp; private</p>", recipients: [outsider.activityPubProfile,
                "https://www.w3.org/ns/activitystreams#Public"], parent: "https://remote.example/another-thread")

            // Act.
            let response = try await application.receivePrivateActivityPubNote(update, sender: remote,
                inbox: personalInbox ? "/actors/\(local.userName)/inbox" : "/shared/inbox", activityType: .update)
            let status = try #require(try await Status.find(statusId, on: application.db))
            let inboxAfter = try #require(try await UserDirectConversation.find(inboxBefore.id, on: application.db))
            let recipientAfter = try #require(try await StatusRecipient.find(recipientBefore.id, on: application.db))

            // Assert.
            #expect(response.status == .ok)
            #expect(status.note == update.content)
            #expect(status.sensitive)
            #expect(status.contentWarning == "Edited warning")
            #expect(status.updatedByUserAt != nil)
            #expect(status.visibility == .mentioned)
            #expect(status.$directConversation.id == conversationId)
            #expect(status.$replyToStatus.id == original.$replyToStatus.id)
            #expect(status.replyToActivityPubId == original.replyToActivityPubId)
            #expect(inboxAfter.summary == "Edited & private")
            #expect(inboxAfter.lastActivityAt == inboxBefore.lastActivityAt)
            #expect(inboxAfter.lastReadAt == inboxBefore.lastReadAt)
            #expect(recipientAfter.readAt == recipientBefore.readAt)
            #expect(try await application.services.directMessagesService.unreadCount(userId: local.requireID(),
                on: executionContext) == 0)
            #expect(try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == statusId)
                .count() == 1)
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == conversationId)
                .filter(\.$user.$id == outsider.requireID())
                .count() == 0)
            #expect(try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == statusId)
                .count() == notificationCount)
            #expect(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == statusId)
                .count() == 0)
            #expect(try await UserStatus.query(on: application.db)
                .filter(\.$status.$id == statusId)
                .count() == 0)
            #expect(try await application.getStatusHistory(statusId: statusId)?.note == note.content)
        }

        @Test
        func `Editing an earlier message preserves the newer preview and ignores repeated or older versions`() async throws {
            // Arrange.
            let remote = try await application.createRemoteDirectMessageUser()
            let local = try await application.createDirectMessageUser()
            let root = privateActivityPubNote(sender: remote, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(root, sender: remote)
            let reply = privateActivityPubNote(sender: remote, recipients: [local], parent: root.id, content: "Latest message")
            _ = try await application.receivePrivateActivityPubNote(reply, sender: remote)
            let original = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == root.id)
                .first())
            let conversationId = try #require(original.$directConversation.id)
            let update = edited(root, content: "Edited root")
            let stale = edited(root, content: "Stale root", updated: "2026-10-10T10:00:00Z")

            // Act.
            _ = try await application.receivePrivateActivityPubNote(update, sender: remote, activityType: .update)
            _ = try await application.receivePrivateActivityPubNote(update, sender: remote, activityType: .update)
            _ = try await application.receivePrivateActivityPubNote(stale, sender: remote, activityType: .update)
            let status = try #require(try await Status.find(original.id, on: application.db))
            let inbox = try #require(try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == conversationId)
                .first())

            // Assert.
            #expect(status.note == "Edited root")
            #expect(inbox.summary == "Latest message")
            #expect(try await StatusHistory.query(on: application.db)
                .filter(\.$orginalStatus.$id == original.requireID())
                .count() == 1)
        }

        @Test(arguments: ["actor", "attribution", "signature"])
        func `Private Update rejects forged ownership or signature`(forgery: String) async throws {
            // Arrange.
            let remote = try await application.createRemoteDirectMessageUser()
            let stranger = try await application.createRemoteDirectMessageUser()
            let local = try await application.createDirectMessageUser()
            let note = privateActivityPubNote(sender: remote, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(note, sender: remote)
            let update = edited(note, content: "Forged edit", attributedTo: forgery == "attribution" ? stranger.activityPubProfile : nil)

            // Act.
            _ = try await application.receivePrivateActivityPubNote(update, sender: forgery == "actor" ? stranger : remote,
                invalidSignature: forgery == "signature", activityType: .update)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())

            // Assert.
            #expect(status.note == note.content)
            #expect(status.updatedByUserAt == nil)
            #expect(try await StatusHistory.query(on: application.db)
                .filter(\.$orginalStatus.$id == status.requireID())
                .count() == 0)
        }

        @Test
        func `Private Update cannot resurrect a deleted message`() async throws {
            // Arrange.
            let remote = try await application.createRemoteDirectMessageUser()
            let local = try await application.createDirectMessageUser()
            let note = privateActivityPubNote(sender: remote, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(note, sender: remote)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())
            try await application.services.statusesService.delete(id: status.requireID(), on: executionContext)

            // Act.
            _ = try await application.receivePrivateActivityPubNote(edited(note, content: "Resurrected"), sender: remote, activityType: .update)

            // Assert.
            #expect(try await Status.find(status.id, on: application.db) == nil)
            #expect(try await DeletedDirectMessage.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 1)
        }

        @Test
        func `Private Update adds and removes photos while retaining previous media in history`() async throws {
            // Arrange.
            let remote = try await application.createRemoteDirectMessageUser()
            let local = try await application.createDirectMessageUser()
            let originalService = application.services.temporaryFileService
            application.services.temporaryFileService = FixtureTemporaryFileService(base: originalService)

            defer { application.services.temporaryFileService = originalService }
            let note = privateActivityPubNote(sender: remote, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(note, sender: remote)
            let image = MediaAttachmentDto(mediaType: "image/png", url: FixtureTemporaryFileService.imageUrl,
                name: "Edited photo", blurhash: nil, width: 1706, height: 882, hdrImageUrl: nil, exif: nil, exifData: nil, location: nil)

            // Act.
            _ = try await application.receivePrivateActivityPubNote(edited(note, content: "", attachments: [image]),
                sender: remote, activityType: .update)
            let attachment = try await application.getAttachment(userId: remote.requireID())

            defer { application.clearFiles(attachments: [attachment]) }
            let statusId = try #require(attachment.$status.id)
            let imageInbox = try #require(try await UserDirectConversation.query(on: application.db)
                .filter(\.$lastStatus.$id == statusId)
                .first())
            _ = try await application.receivePrivateActivityPubNote(edited(note, content: "Text again", updated: "2026-10-11T12:00:00Z"),
                sender: remote, activityType: .update)
            let status = try #require(try await application.services.statusesService.get(id: statusId, on: application.db))
            let histories = try await application.services.statusesService.get(history: statusId, on: application.db)

            // Assert.
            #expect(imageInbox.summary == "Image")
            #expect(status.attachments.isEmpty)
            #expect(status.note == "Text again")
            #expect(histories.count == 2)
            #expect(histories.contains { $0.attachments.first?.description == "Edited photo" })
            #expect(try await Attachment.find(attachment.id, on: application.db)?.$status.id == nil)
        }

        private var executionContext: ExecutionContext {
            Request(application: application, on: application.eventLoopGroup.next()).executionContext
        }

        private func edited(_ note: NoteDto, content: String, updated: String = "2026-10-11T11:00:00Z",
                            recipients: [String]? = nil, parent: String? = nil, attributedTo: String? = nil,
                            attachments: [MediaAttachmentDto] = []) -> NoteDto {
            NoteDto(id: note.id, summary: "Edited warning", inReplyTo: parent ?? note.inReplyTo,
                published: note.published, updated: updated, url: note.url, attributedTo: attributedTo ?? note.attributedTo,
                to: recipients.map { .multiple($0.map { ActorDto(id: $0) }) } ?? note.to, cc: note.cc,
                sensitive: true, atomUri: nil, inReplyToAtomUri: nil, conversation: nil,
                content: content, attachment: attachments, tag: nil)
        }
    }
}
