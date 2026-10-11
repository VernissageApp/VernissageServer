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

@Suite("Direct messages account deletion", .serialized)
struct DirectMessagesAccountDeletionTests {
    let application: Application

    init() async throws {
        application = try await ApplicationManager.shared.application()
    }

    @Test(arguments: [true, false])
    func `Deleting an account removes a two person conversation`(isLocal: Bool) async throws {
        // Arrange.
        let author = try await createAuthor(isLocal: isLocal)
        let recipient = try await application.createDirectMessageUser()
        let message = try await createMessage(author: author, recipients: [recipient])
        let attachment = try await application.createAttachment(user: recipient)
        let reply = try await application.sendDirectMessage(
            author: recipient,
            recipients: [author],
            conversationId: message.conversationId,
            attachmentIds: [attachment.stringId()!])

        defer { application.clearFiles(attachments: [attachment]) }

        // Act.
        try await deleteAccount(author)

        // Assert.
        let conversationId = try requireDirectMessageId(message.conversationId)
        #expect(try await DirectConversation.find(conversationId, on: application.db) == nil)
        #expect(try await Status.find(requireDirectMessageId(reply.id), on: application.db) == nil)
        #expect(try await DeletedDirectMessage.query(on: application.db)
            .filter(\.$conversation.$id == conversationId).count() == 0)
        #expect(try await UserDirectConversation.query(on: application.db)
            .filter(\.$conversation.$id == conversationId).count() == 0)
        let detachedAttachment = try #require(try await Attachment.find(attachment.requireID(), on: application.db))
        #expect(detachedAttachment.$status.id == nil)
    }

    @Test(arguments: [true, false])
    func `Group history removes authored messages and markers but preserves other messages`(isLocal: Bool) async throws {
        // Arrange.
        let author = try await createAuthor(isLocal: isLocal)
        let first = try await application.createDirectMessageUser()
        let second = try await application.createDirectMessageUser()
        let root = try await createMessage(author: author, recipients: [first, second])
        let reply = try await application.sendDirectMessage(
            author: first,
            recipients: [author, second],
            note: "Keep this message",
            conversationId: root.conversationId,
            replyToStatusId: root.id)

        let latest = try await createMessage(author: author, recipients: [first, second], parent: reply)
        let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext
        let conversationId = try requireDirectMessageId(root.conversationId)
        try await application.services.statusesService.delete(id: requireDirectMessageId(root.id), on: context)
        try await application.services.directMessagesService.markRead(conversationId: conversationId,
            statusIds: [reply.id], userId: second.requireID(), on: context)
        try await application.services.directMessagesService.mute(conversationId: conversationId,
            userId: second.requireID(), isMuted: true, on: context)

        // Act.
        try await deleteAccount(author)

        // Assert.
        let messages = try await application.services.directMessagesService.messages(conversationId: conversationId,
            userId: second.requireID(), page: 1, size: 20, on: context)
        let inbox = try await application.services.directMessagesService.conversation(id: conversationId,
            userId: second.requireID(), on: context)
        #expect(messages.total == 1)
        #expect(messages.data.map(\.id) == [reply.id])
        #expect(messages.data.first?.recipients.contains { $0.id == author.stringId() } == false)
        #expect(messages.data.first?.replyToStatusId == nil)
        #expect(messages.data.first?.readAt != nil)
        #expect(inbox.summary == "Keep this message")
        #expect(inbox.lastStatusId == reply.id)
        #expect(inbox.lastMessageDeletedAt == nil)
        #expect(inbox.hasUnreadMessages == false)
        #expect(inbox.isMuted)
        #expect(inbox.participants.contains { $0.id == author.stringId() } == false)
        #expect(try await Status.find(requireDirectMessageId(latest.id), on: application.db) == nil)
        #expect(try await DeletedDirectMessage.query(on: application.db)
            .filter(\.$author.$id == author.requireID()).count() == 0)
        #expect(try await UserDirectConversation.query(on: application.db)
            .filter(\.$user.$id == author.requireID()).count() == 0)
    }

    @Test(arguments: [true, false])
    func `Deleting a recipient removes addressing from live messages and other authors markers`(isLocal: Bool) async throws {
        // Arrange.
        let recipient = try await createAuthor(isLocal: isLocal)
        let author = try await application.createDirectMessageUser()
        let other = try await application.createDirectMessageUser()
        let root = try await application.sendDirectMessage(
            author: author,
            recipients: [recipient, other])

        let reply = try await application.sendDirectMessage(
            author: other,
            recipients: [recipient, author],
            conversationId: root.conversationId)

        let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext
        try await application.services.statusesService.delete(id: requireDirectMessageId(root.id), on: context)

        // Act.
        try await deleteAccount(recipient)

        // Assert.
        let conversationId = try requireDirectMessageId(root.conversationId)
        let messages = try await application.services.directMessagesService.messages(conversationId: conversationId,
            userId: author.requireID(), page: 1, size: 20, on: context)
        #expect(messages.total == 2)
        #expect(messages.data.first?.id == reply.id)
        #expect(messages.data.last?.deletedAt != nil)
        #expect(messages.data.allSatisfy { message in
            message.recipients.contains { $0.id == recipient.stringId() } == false
        })
        #expect(try await StatusRecipient.query(on: application.db)
            .filter(\.$user.$id == recipient.requireID()).count() == 0)
        #expect(try await DeletedDirectMessageRecipient.query(on: application.db)
            .filter(\.$user.$id == recipient.requireID()).count() == 0)
    }

    @Test
    func `A remaining remote participant keeps the group conversation alive`() async throws {
        // Arrange.
        let author = try await application.createDirectMessageUser()
        let local = try await application.createDirectMessageUser()
        let remote = try await application.createRemoteDirectMessageUser()
        let root = try await application.sendDirectMessage(
            author: author,
            recipients: [local, remote])

        let reply = try await application.sendDirectMessage(
            author: local,
            recipients: [author, remote],
            note: "Still a group",
            conversationId: root.conversationId)

        let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext

        // Act.
        try await deleteAccount(author)

        // Assert.
        let conversationId = try requireDirectMessageId(root.conversationId)
        #expect(try await DirectConversation.find(conversationId, on: application.db) != nil)
        let messages = try await application.services.directMessagesService.messages(conversationId: conversationId,
            userId: local.requireID(), page: 1, size: 20, on: context)
        #expect(messages.data.map(\.id) == [reply.id])
        #expect(messages.data.first?.recipients.map(\.id) == [remote.stringId()!])
    }

    @Test
    func `Rebuilding a group inbox does not reveal another participants messages`() async throws {
        // Arrange.
        let author = try await application.createDirectMessageUser()
        let first = try await application.createDirectMessageUser()
        let second = try await application.createDirectMessageUser()
        let third = try await application.createDirectMessageUser()
        let root = try await application.sendDirectMessage(
            author: author,
            recipients: [first, second, third])

        let privateReply = try await application.sendDirectMessage(
            author: first,
            recipients: [second],
            note: "Not visible to third",
            conversationId: root.conversationId)

        let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext

        // Act.
        try await deleteAccount(author)

        // Assert.
        let conversationId = try requireDirectMessageId(root.conversationId)
        let inbox = try await application.services.directMessagesService.conversation(id: conversationId,
            userId: third.requireID(), on: context)
        let messages = try await application.services.directMessagesService.messages(conversationId: conversationId,
            userId: third.requireID(), page: 1, size: 20, on: context)
        #expect(inbox.summary == nil)
        #expect(inbox.lastStatusId == nil)
        #expect(inbox.hasUnreadMessages == false)
        #expect(messages.total == 0)
        #expect(try await Status.find(requireDirectMessageId(privateReply.id), on: application.db) != nil)
    }

    private func createAuthor(isLocal: Bool) async throws -> User {
        if isLocal {
            return try await application.createDirectMessageUser()
        }

        return try await application.createRemoteDirectMessageUser()
    }

    private func createMessage(author: User, recipients: [User], parent: DirectMessageDto? = nil) async throws -> DirectMessageDto {
        if author.isLocal {
            return try await application.sendDirectMessage(
                author: author,
                recipients: recipients,
                conversationId: parent?.conversationId,
                replyToStatusId: parent?.id)

        }

        var status: Status?

        if let parent {
            status = try await Status.find(requireDirectMessageId(parent.id), on: application.db)
        }

        let note = privateActivityPubNote(sender: author, recipients: recipients, parent: status?.activityPubId)
        let response = try await application.receivePrivateActivityPubNote(note, sender: author)
        #expect(response.status == .ok)
        let stored = try #require(try await Status.query(on: application.db).filter(\.$activityPubId == note.id).first())
        let conversationId = try #require(stored.$directConversation.id)
        let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext
        let messages = try await application.services.directMessagesService.messages(conversationId: conversationId,
            userId: recipients[0].requireID(), page: 1, size: 20, on: context)

        return try #require(messages.data.first { $0.id == stored.stringId() })
    }

    private func deleteAccount(_ user: User) async throws {
        if user.isLocal {
            let response = try await application.sendRequest(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/users/@\(user.userName)",
                method: .DELETE)

            #expect(response.status == .ok)
        } else {
            let activity = ActivityDto(context: .single(ContextDto(value: "https://www.w3.org/ns/activitystreams")),
                type: .delete, id: user.activityPubProfile + "/delete", actor: .single(ActorDto(id: user.activityPubProfile)),
                object: .single(ObjectDto(id: user.activityPubProfile, type: .person)), summary: nil, signature: nil)
            let response = try await application.receiveSignedPrivateActivity(activity, sender: user)
            #expect(response.status == .ok)
            #expect(try await User.query(on: application.db).withDeleted().filter(\.$id == user.requireID()).count() == 0)
        }
    }
}
