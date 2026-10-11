//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Fluent
import Vapor
import Testing

extension ControllersTests {
    @Suite("ActivityPubShared (POST /shared/inbox [Create])", .serialized, .tags(.shared))
    struct ActivityPubSharedCreateTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test(arguments: [1, 2, 3])
        func `Private Create discards cyclic parent links while preserving messages`(messageCount: Int) async throws {
            // Arrange.
            let sender = try await application.createRemoteDirectMessageUser()
            let recipient = try await application.createDirectMessageUser()
            let ids = (0..<messageCount).map { sender.activityPubProfile + "/statuses/" + UUID().uuidString + "/\($0)" }

            // Act.
            for index in ids.indices {
                let note = privateActivityPubNote(sender: sender, recipients: [recipient], id: ids[index],
                                                 parent: ids[(index + 1) % messageCount])
                let response = try await application.receivePrivateActivityPubNote(note, sender: sender)
                #expect(response.status == .ok)
            }

            // Assert.
            let statuses = try await Status.query(on: application.db)
                .filter(\.$activityPubId ~~ ids).all()
            #expect(statuses.count == messageCount)
            #expect(Set(statuses.compactMap { $0.$directConversation.id }).count == 1)

            for index in ids.indices {
                let status = try #require(statuses.first { $0.activityPubId == ids[index] })
                #expect(status.note == "<p>Private hello</p>")

                if index == messageCount - 1 {
                    #expect(status.$replyToStatus.id == nil)
                    #expect(status.replyToActivityPubId == nil)
                } else {
                    let parent = try #require(statuses.first { $0.activityPubId == ids[index + 1] })
                    #expect(status.$replyToStatus.id == parent.id)
                }
            }
        }

        @Test
        func `A late private parent cannot form a cycle through a deleted pending reply`() async throws {
            // Arrange.
            let sender = try await application.createRemoteDirectMessageUser()
            let recipient = try await application.createDirectMessageUser()
            let parentId = sender.activityPubProfile + "/statuses/" + UUID().uuidString
            let reply = privateActivityPubNote(sender: sender, recipients: [recipient], parent: parentId)
            _ = try await application.receivePrivateActivityPubNote(reply, sender: sender)
            let stored = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == reply.id).first())
            let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext
            try await application.services.statusesService.delete(id: stored.requireID(), on: context)
            let parent = privateActivityPubNote(sender: sender, recipients: [recipient], id: parentId, parent: reply.id)

            // Act.
            let response = try await application.receivePrivateActivityPubNote(parent, sender: sender)

            // Assert.
            #expect(response.status == .ok)
            let received = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == parentId).first())
            let marker = try #require(try await DeletedDirectMessage.find(stored.requireID(), on: application.db))
            #expect(received.replyToActivityPubId == nil)
            #expect(received.$replyToStatus.id == nil)
            #expect(marker.replyToStatusId == received.id)
            #expect(marker.$conversation.id == received.$directConversation.id)
        }

        @Test
        func `A public Create cannot resurrect a deleted private object`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let privateNote = privateActivityPubNote(sender: sender, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(privateNote, sender: sender)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == privateNote.id)
                .first())
            let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext

            try await application.services.statusesService.delete(id: status.requireID(), on: context)
            _ = try await application.createFollow(sourceId: local.requireID(), targetId: sender.requireID(), approved: true)
            let original = application.services.temporaryFileService
            application.services.temporaryFileService = FixtureTemporaryFileService(base: original)

            defer { application.services.temporaryFileService = original }
            let publicNote = NoteDto(id: privateNote.id, summary: nil, inReplyTo: nil, published: privateNote.published, updated: nil,
                url: privateNote.id, attributedTo: sender.activityPubProfile,
                to: .single(ActorDto(id: "https://www.w3.org/ns/activitystreams#Public")), cc: nil, sensitive: false,
                atomUri: nil, inReplyToAtomUri: nil, conversation: nil, content: "Public replacement",
                attachment: [MediaAttachmentDto(mediaType: "image/png", url: FixtureTemporaryFileService.imageUrl, name: nil,
                    blurhash: nil, width: 1706, height: 882, hdrImageUrl: nil, exif: nil, exifData: nil, location: nil)], tag: nil)

            // Act.
            let response = try await application.receivePrivateActivityPubNote(publicNote, sender: sender)

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.query(on: application.db)
                .filter(\.$activityPubId == privateNote.id)
                .count() == 0)
            #expect(try await DeletedDirectMessage.find(status.requireID(), on: application.db) != nil)
        }

        @Test
        func `A signed sender cannot claim a note id on another origin`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [local], id: "https://another.example/statuses/forged")

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender)

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 0)
        }

        @Test
        func `An explicit cc recipient receives a private message`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [sender], ccRecipients: [local])

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())

            // Assert.
            #expect(response.status == .ok)
            #expect(try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .filter(\.$user.$id == local.requireID())
                .count() == 1)
            #expect(try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .filter(\.$user.$id == local.requireID())
                .first()?.recipientType == .cc)
        }

        @Test
        func `An empty object audience cannot be widened by envelope addressing or text mentions`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [], content: "Hello @" + local.userName)

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender, envelopeTo: [local.activityPubProfile])

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 0)
        }

        @Test
        func `Repeated Create cannot resurrect a deleted private message`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(note, sender: sender)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())
            let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext

            try await application.services.statusesService.delete(id: status.requireID(), on: context)

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender)

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 0)
            #expect(try await DeletedDirectMessage.find(status.requireID(), on: application.db) != nil)
        }

        @Test
        func `An attachment only private message downloads its image without a public timeline entry`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let original = application.services.temporaryFileService
            application.services.temporaryFileService = FixtureTemporaryFileService(base: original)

            defer { application.services.temporaryFileService = original }
            let id = sender.activityPubProfile + "/statuses/" + UUID().uuidString
            let note = NoteDto(id: id, summary: nil, inReplyTo: nil, published: Date().toISO8601String(), updated: nil,
                url: id, attributedTo: sender.activityPubProfile, to: .single(ActorDto(id: local.activityPubProfile)), cc: nil,
                sensitive: false, atomUri: nil, inReplyToAtomUri: nil, conversation: nil, content: nil,
                attachment: [MediaAttachmentDto(mediaType: "image/png", url: FixtureTemporaryFileService.imageUrl,
                    name: "Private photo", blurhash: nil, width: 1706, height: 882, hdrImageUrl: nil, exif: nil, exifData: nil, location: nil)], tag: nil)

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == id)
                .first())
            let attachment = try await application.getAttachment(userId: sender.requireID())

            defer { application.clearFiles(attachments: [attachment]) }
            let conversationId = try #require(status.$directConversation.id)
            let inbox = try #require(try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == conversationId)
                .first())

            // Assert.
            #expect(response.status == .ok)
            #expect(attachment.$status.id == status.id)
            #expect(inbox.summary == "Image")
            #expect(try await UserStatus.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .count() == 0)
        }

        @Test
        func `Envelope addressing is used only when the note omits both to and cc`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let id = sender.activityPubProfile + "/statuses/" + UUID().uuidString
            let note = NoteDto(id: id, summary: nil, inReplyTo: nil, published: Date().toISO8601String(), updated: nil,
                url: id, attributedTo: sender.activityPubProfile, to: nil, cc: nil, sensitive: false,
                atomUri: nil, inReplyToAtomUri: nil, conversation: nil, content: "Envelope only", attachment: nil, tag: nil)

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender, envelopeTo: [local.activityPubProfile])
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == id)
                .first())

            // Assert.
            #expect(response.status == .ok)
            #expect(status.$directConversation.id != nil)
        }

        @Test
        func `A deleted pending reply is reconciled when its parent arrives`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let root = privateActivityPubNote(sender: sender, recipients: [local])
            let child = privateActivityPubNote(sender: sender, recipients: [local], parent: root.id)
            _ = try await application.receivePrivateActivityPubNote(child, sender: sender)
            let pending = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == child.id)
                .first())
            let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext

            try await application.services.statusesService.delete(id: pending.requireID(), on: context)

            // Act.
            let response = try await application.receivePrivateActivityPubNote(root, sender: sender)
            let storedRoot = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == root.id)
                .first())
            let marker = try #require(try await DeletedDirectMessage.find(pending.requireID(), on: application.db))

            // Assert.
            #expect(response.status == .ok)
            #expect(marker.$conversation.id == storedRoot.$directConversation.id)
            #expect(marker.replyToStatusId == storedRoot.id)
            #expect(marker.replyToActivityPubId == root.id)
        }

        @Test
        func `Text only private Create reaches every explicit local inbox without timeline entries`() async throws {
            // Arrange.
            let sender = try await application.createRemoteDirectMessageUser()
            let remote = try await application.createRemoteDirectMessageUser()
            let first = try await application.createDirectMessageUser()
            let second = try await application.createDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [first, second, remote])

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())
            let conversationId = try #require(status.$directConversation.id)
            let firstInbox = try await application.getResponse(
                as: .user(userName: first.userName, password: "p@ssword"),
                to: "/direct-messages/\(conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            // Assert.
            #expect(response.status == .ok)
            #expect(status.visibility == .mentioned)
            #expect(status.isLocal == false)
            #expect(status.note == note.content)
            #expect(firstInbox.hasUnreadMessages)
            #expect(firstInbox.summary == "Private hello")
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == conversationId)
                .count() == 2)
            #expect(try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .count() == 3)
            #expect(try await UserStatus.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .count() == 0)
            let notifications = try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .all()
            #expect(notifications.count == 2)
            #expect(notifications.allSatisfy { $0.notificationType == .directMessage })
            #expect(try await User.find(sender.requireID(), on: application.db)?.statusesCount == 0)
        }

        @Test
        func `Reply to a local private message joins its conversation without sharing history with a new recipient`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let newcomer = try await application.createDirectMessageUser()
            let root = try await application.sendDirectMessage(
                author: local,
                recipients: [sender])

            let note = privateActivityPubNote(sender: sender, recipients: [local, newcomer], parent: root.status?.activityPubId)

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())
            let messages = try await application.getResponse(
                as: .user(userName: newcomer.userName, password: "p@ssword"),
                to: "/direct-messages/\(root.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            // Assert.
            #expect(response.status == .ok)
            #expect(status.$directConversation.id == root.conversationId.toId())
            #expect(status.$replyToStatus.id == root.id.toId())
            #expect(messages.data.map(\.id) == [status.stringId()])
            #expect(try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .filter(\.$notificationType == .newComment)
                .count() == 0)
        }

        @Test
        func `Reply to a deleted private message joins the original conversation`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let root = try await application.sendDirectMessage(
                author: local,
                recipients: [sender])

            _ = try await application.sendRequest(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/statuses/\(root.id)",
                method: .DELETE)

            let note = privateActivityPubNote(sender: sender, recipients: [local], parent: root.status?.activityPubId)

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender)
            let messages = try await application.getResponse(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/direct-messages/\(root.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            // Assert.
            #expect(response.status == .ok)
            #expect(messages.total == 2)
            #expect(messages.data.first?.replyToStatusId == root.id)
            #expect(messages.data.last?.deletedAt != nil)
        }

        @Test
        func `An inaccessible parent does not let a remote sender join an existing conversation`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let addressed = try await application.createRemoteDirectMessageUser()
            let stranger = try await application.createRemoteDirectMessageUser()
            let root = try await application.sendDirectMessage(
                author: local,
                recipients: [addressed])

            let note = privateActivityPubNote(sender: stranger, recipients: [local], parent: root.status?.activityPubId)

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: stranger)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())

            // Assert.
            #expect(response.status == .ok)
            #expect(status.$directConversation.id != root.conversationId.toId())
            #expect(status.$replyToStatus.id == nil)
            #expect(status.replyToActivityPubId == root.status?.activityPubId)
        }

        @Test
        func `A late parent merges provisional conversations and preserves reads and mute preferences`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let rootAuthor = try await application.createRemoteDirectMessageUser()
            let firstAuthor = try await application.createRemoteDirectMessageUser()
            let secondAuthor = try await application.createRemoteDirectMessageUser()
            let root = privateActivityPubNote(sender: rootAuthor, recipients: [local, firstAuthor, secondAuthor])
            let first = privateActivityPubNote(sender: firstAuthor, recipients: [local, rootAuthor], parent: root.id)
            let second = privateActivityPubNote(sender: secondAuthor, recipients: [local, rootAuthor], parent: root.id)
            _ = try await application.receivePrivateActivityPubNote(first, sender: firstAuthor)
            _ = try await application.receivePrivateActivityPubNote(second, sender: secondAuthor)
            let firstStatus = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == first.id)
                .first())
            let secondStatus = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == second.id)
                .first())
            let firstConversation = try #require(firstStatus.$directConversation.id)
            _ = try await application.sendRequest(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/direct-messages/\(firstConversation)/read",
                method: .POST,
                body: DirectConversationReadRequestDto(statusIds: [try #require(firstStatus.stringId())]))

            _ = try await application.sendRequest(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/direct-messages/\(firstConversation)/mute",
                method: .PUT,
                body: DirectConversationMuteRequestDto(isMuted: true))

            // Act.
            let response = try await application.receivePrivateActivityPubNote(root, sender: rootAuthor)
            let rootStatus = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == root.id)
                .first())
            let conversationId = try #require(rootStatus.$directConversation.id)
            let inbox = try await application.getResponse(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/direct-messages/\(conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            let messages = try await application.getResponse(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/direct-messages/\(conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            // Assert.
            #expect(response.status == .ok)
            #expect(messages.total == 3)
            #expect(inbox.isMuted)
            #expect(inbox.hasUnreadMessages)
            #expect(messages.data.first { $0.id == firstStatus.stringId() }?.readAt != nil)
            #expect(try await Status.find(firstStatus.requireID(), on: application.db)?.$replyToStatus.id == rootStatus.id)
            #expect(try await Status.find(secondStatus.requireID(), on: application.db)?.$replyToStatus.id == rootStatus.id)
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$user.$id == local.requireID())
                .count() == 1)
            #expect(try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == rootStatus.requireID())
                .count() == 0)
        }

        @Test
        func `Duplicate delivery through shared and personal inboxes preserves read state and activity`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(note, sender: sender)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())
            let conversationId = try #require(status.$directConversation.id)
            _ = try await application.sendRequest(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/direct-messages/\(conversationId)/read",
                method: .POST,
                body: DirectConversationReadRequestDto(statusIds: [try #require(status.stringId())]))

            let before = try #require(try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == conversationId)
                .first())

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender, inbox: "/actors/\(local.userName)/inbox")
            let after = try #require(try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == conversationId)
                .first())

            // Assert.
            #expect(response.status == .ok)
            #expect(after.lastActivityAt == before.lastActivityAt)
            #expect(after.lastReadAt == before.lastReadAt)
            #expect(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 1)
            #expect(try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .count() == 1)
        }

        @Test
        func `Concurrent deliveries create a single message and conversation`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [local])

            // Act.
            async let shared = application.receivePrivateActivityPubNote(note, sender: sender)
            async let personal = application.receivePrivateActivityPubNote(note, sender: sender, inbox: "/actors/\(local.userName)/inbox")
            let responses = try await (shared, personal)

            // Assert.
            #expect(responses.0.status == .ok)
            #expect(responses.1.status == .ok)
            #expect(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 1)
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$user.$id == local.requireID())
                .count() == 1)
        }

        @Test
        func `Object addressing takes precedence over a public envelope`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [local])

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender,
                envelopeTo: ["https://www.w3.org/ns/activitystreams#Public"])
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())

            // Assert.
            #expect(response.status == .ok)
            #expect(status.visibility == .mentioned)
            #expect(status.$directConversation.id != nil)
        }

        @Test
        func `Invalid signatures and forged note authors cannot create private messages`() async throws {
            // Arrange.
            let local = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let other = try await application.createRemoteDirectMessageUser()
            let note = privateActivityPubNote(sender: sender, recipients: [local])

            // Act.
            let invalid = try await application.receivePrivateActivityPubNote(note, sender: sender, invalidSignature: true)
            let forged = try await application.receivePrivateActivityPubNote(note, sender: other)

            // Assert.
            #expect(invalid.status == .badRequest)
            #expect(forged.status == .ok)
            #expect(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .count() == 0)
        }

        @Test
        func `User blocks exclude only the blocking local recipient`() async throws {
            // Arrange.
            let blocked = try await application.createDirectMessageUser()
            let allowed = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let block = UserBlockedUser(id: application.services.snowflakeService.generate(),
                userId: try blocked.requireID(), blockedUserId: try sender.requireID(), reason: nil)
            try await block.create(on: application.db)
            let note = privateActivityPubNote(sender: sender, recipients: [blocked, allowed])

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())
            let audience = try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .all()

            // Assert.
            #expect(response.status == .ok)
            #expect(audience.map { $0.$user.id } == [allowed.id])
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$user.$id == blocked.requireID())
                .count() == 0)
        }

        @Test(arguments: [true, false], [true, false])
        func `Blocking a co recipient in to or cc excludes only the blocking local user`(peerIsLocal: Bool, peerInCc: Bool) async throws {
            // Arrange.
            let blocking = try await application.createDirectMessageUser()
            let allowed = try await application.createDirectMessageUser()
            let peer = try await application.createDirectMessageUser(isLocal: peerIsLocal)
            let sender = try await application.createRemoteDirectMessageUser()
            _ = try await application.createUserBlockedUser(userId: blocking.requireID(), blockedUserId: peer.requireID(), reason: "Blocked")
            let note = privateActivityPubNote(sender: sender,
                recipients: peerInCc ? [blocking, allowed] : [blocking, allowed, peer],
                ccRecipients: peerInCc ? [peer] : [])

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender)

            // Assert.
            #expect(response.status == .ok)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id).first())
            let audience = try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == status.requireID()).all()
            #expect(Set(audience.map { $0.$user.id }) == Set([try allowed.requireID(), try peer.requireID()]))
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$user.$id == blocking.requireID()).count() == 0)
            #expect(try await Notification.query(on: application.db)
                .filter(\.$user.$id == blocking.requireID()).count() == 0)
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$user.$id == allowed.requireID()).count() == 1)
        }

        @Test
        func `A private note is not stored when every local recipient blocks a remote co recipient`() async throws {
            // Arrange.
            let blocking = try await application.createDirectMessageUser()
            let peer = try await application.createRemoteDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            _ = try await application.createUserBlockedUser(userId: blocking.requireID(), blockedUserId: peer.requireID(), reason: "Blocked")
            let note = privateActivityPubNote(sender: sender, recipients: [blocking], ccRecipients: [peer])

            // Act.
            let response = try await application.receivePrivateActivityPubNote(note, sender: sender)

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.query(on: application.db).filter(\.$activityPubId == note.id).count() == 0)
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$user.$id == blocking.requireID()).count() == 0)
            #expect(try await Notification.query(on: application.db)
                .filter(\.$user.$id == blocking.requireID()).count() == 0)
        }

        @Test
        func `Federated group replies preserve a blocking users inbox until the blocked participant is omitted`() async throws {
            // Arrange.
            let blocking = try await application.createDirectMessageUser()
            let peer = try await application.createDirectMessageUser()
            let sender = try await application.createRemoteDirectMessageUser()
            let root = privateActivityPubNote(sender: sender, recipients: [blocking, peer], content: "<p>Original</p>")
            _ = try await application.receivePrivateActivityPubNote(root, sender: sender)
            let status = try #require(try await Status.query(on: application.db).filter(\.$activityPubId == root.id).first())
            let conversationId = try #require(status.$directConversation.id)
            let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext
            try await application.services.directMessagesService.markRead(conversationId: conversationId,
                statusIds: [try status.requireID().description], userId: blocking.requireID(), on: context)
            _ = try await application.createUserBlockedUser(userId: blocking.requireID(), blockedUserId: peer.requireID(), reason: "Blocked")
            let before = try await application.services.directMessagesService.conversation(id: conversationId,
                userId: blocking.requireID(), on: context)
            let group = privateActivityPubNote(sender: sender, recipients: [blocking, peer], parent: root.id)
            let smaller = privateActivityPubNote(sender: sender, recipients: [blocking], parent: group.id, content: "<p>Only you</p>")

            // Act.
            _ = try await application.receivePrivateActivityPubNote(group, sender: sender)
            let afterGroup = try await application.services.directMessagesService.conversation(id: conversationId,
                userId: blocking.requireID(), on: context)
            _ = try await application.receivePrivateActivityPubNote(smaller, sender: sender)

            // Assert.
            #expect(afterGroup.summary == before.summary)
            #expect(afterGroup.lastStatusId == before.lastStatusId)
            #expect(afterGroup.lastActivityAt == before.lastActivityAt)
            #expect(afterGroup.hasUnreadMessages == false)
            let messages = try await application.services.directMessagesService.messages(conversationId: conversationId,
                userId: blocking.requireID(), page: 1, size: 20, on: context)
            #expect(messages.total == 2)
            #expect(Set(messages.data.compactMap { $0.status?.activityPubId }) == Set([root.id, smaller.id]))
            let afterSmaller = try await application.services.directMessagesService.conversation(id: conversationId,
                userId: blocking.requireID(), on: context)
            #expect(afterSmaller.summary == "Only you")
            #expect(afterSmaller.hasUnreadMessages)
        }
    }
}
