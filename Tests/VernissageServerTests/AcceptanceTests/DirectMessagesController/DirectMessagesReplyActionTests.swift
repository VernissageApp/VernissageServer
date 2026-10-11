//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Testing
import Vapor
import ActivityPubKit
import Queues

extension ControllersTests {
    @Suite("DirectMessages (POST /direct-messages/123/statuses)", .serialized, .tags(.directMessages))
    struct DirectMessagesReplyActionTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Blocking a group participant preserves history and accepts a later smaller audience`() async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let blocking = try await application.createDirectMessageUser()
            let blocked = try await application.createDirectMessageUser()
            let root = try await application.sendDirectMessage(
                author: author,
                recipients: [blocking, blocked],
                note: "Original")

            _ = try await application.createUserBlockedUser(userId: blocking.requireID(), blockedUserId: blocked.requireID(), reason: "Blocked")
            let context = Request(application: application, on: application.eventLoopGroup.next()).executionContext
            let conversationId = try requireDirectMessageId(root.conversationId)
            try await application.services.directMessagesService.markRead(conversationId: conversationId,
                statusIds: [root.id], userId: blocking.requireID(), on: context)
            let before = try await application.services.directMessagesService.conversation(id: conversationId,
                userId: blocking.requireID(), on: context)

            // Act.
            let excluded = try await application.sendDirectMessage(
                author: author,
                recipients: [blocking, blocked],
                note: "Group reply",
                conversationId: root.conversationId)

            let afterExcluded = try await application.services.directMessagesService.conversation(id: conversationId,
                userId: blocking.requireID(), on: context)
            let smaller = try await application.sendDirectMessage(
                author: author,
                recipients: [blocking],
                note: "Only you",
                conversationId: root.conversationId)

            // Assert.
            #expect(excluded.recipients.map(\.id) == [blocked.stringId()!])
            #expect(afterExcluded.summary == before.summary)
            #expect(afterExcluded.lastStatusId == before.lastStatusId)
            #expect(afterExcluded.lastActivityAt == before.lastActivityAt)
            #expect(afterExcluded.hasUnreadMessages == false)
            let messages = try await application.services.directMessagesService.messages(conversationId: conversationId,
                userId: blocking.requireID(), page: 1, size: 20, on: context)
            #expect(messages.data.map(\.id) == [smaller.id, root.id])
            let afterSmaller = try await application.services.directMessagesService.conversation(id: conversationId,
                userId: blocking.requireID(), on: context)
            #expect(afterSmaller.summary == "Only you")
            #expect(afterSmaller.hasUnreadMessages)
            #expect(try await Notification.query(on: application.db)
                .filter(\.$user.$id == blocking.requireID())
                .filter(\.$status.$id == requireDirectMessageId(excluded.id)).count() == 0)
        }

        @Test(arguments: [true, false])
        func `Federated reply to a deleted message preserves parent id and addresses only its selected audience`(explicitParent: Bool) async throws {
            // Arrange.
            let sender = try await application.createUser(userName: "sender" + UUID().uuidString, generateKeys: true)
            let first = try await application.createDirectMessageUser(isLocal: false)
            let second = try await application.createDirectMessageUser(isLocal: false)
            let root = try await application.sendDirectMessage(
                author: sender,
                recipients: [first, second])

            _ = try await application.sendRequest(
                as: .user(userName: sender.userName, password: "p@ssword"),
                to: "/statuses/\(root.id)",
                method: .DELETE)

            let session = DirectMessageDeliveryURLProtocol.session()

            defer { session.invalidateAndCancel() }
            let previous = application.services.activityPubOutgoingStatusService
            application.services.activityPubOutgoingStatusService = ActivityPubOutgoingStatusService(urlSession: session)

            defer { application.services.activityPubOutgoingStatusService = previous }

            // Act.
            let reply = try await application.sendDirectMessage(
                author: sender,
                recipients: [second],
                note: "Private reply",
                conversationId: root.conversationId,
                replyToStatusId: explicitParent ? root.id : nil)

            let event = try #require(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(reply.id))
                .first())
            try await ActivityPubStatusJob().dequeue(application.getQueueContext(queueName: .apStatus),
                ActivityPubStatusJobDataDto(statusActivityPubEventId: event.requireID()))
            let request = try #require(DirectMessageDeliveryURLProtocol.requests.first)
            let activity = try JSONDecoder().decode(ActivityDto.self, from: #require(request.httpBody))
            let note = try #require(activity.object.objects().first?.object as? NoteDto)

            // Assert.
            #expect(DirectMessageDeliveryURLProtocol.requests.count == 1)
            #expect(request.url?.absoluteString == second.userInbox)
            #expect(activity.to?.actorIds() == [second.activityPubProfile])
            #expect(note.to?.actorIds() == [second.activityPubProfile])
            #expect(note.inReplyTo == root.status?.activityPubId)
            #expect(reply.conversationId == root.conversationId)
        }

        @Test
        func `An accessible deleted message can still be referenced by a reply`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            _ = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)",
                method: .DELETE)

            // Act.
            let reply = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.author],
                note: "Reply after removal",
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            let saved = try #require(try await Status.find(try requireDirectMessageId(reply.id), on: application.db))

            // Assert.
            #expect(reply.replyToStatusId == fixture.message.id)
            #expect(saved.$replyToStatus.id == nil)
            #expect(saved.replyToActivityPubId == fixture.message.status?.activityPubId)
            #expect(reply.deletedAt == nil)
            #expect(reply.status?.note == "Reply after removal")
        }

        @Test
        func `Reply preserves parent and updates only addressed inboxes`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let initial = try #require(try await UserDirectConversation.query(on: application.db)
                .filter(\.$user.$id == fixture.author.requireID())
                .filter(\.$conversation.$id == (try requireDirectMessageId(fixture.message.conversationId)))
                .first())

            // Act.
            let reply = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.outsider],
                note: "Limited reply",
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            let parent = try #require(try await Status.find((try requireDirectMessageId(reply.id)), on: application.db))
            let unchanged = try #require(try await UserDirectConversation.find(initial.id, on: application.db))

            // Assert.
            #expect(reply.status?.replyToStatusId == fixture.message.id)
            #expect(parent.replyToActivityPubId == fixture.message.status?.activityPubId)
            #expect(unchanged.lastActivityAt == initial.lastActivityAt)
            #expect(unchanged.$lastStatus.id == (try requireDirectMessageId(fixture.message.id)))
        }

        @Test
        func `Outsiders and parents from another conversation are rejected`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()

            // Act.
            let outsider = try await application.sendRequest(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: [fixture.author.stringId()!], note: "Hello"))

            let other = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient])

            let wrongParent = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: [fixture.recipient.stringId()!], note: "Hello", replyToStatusId: other.id))

            // Assert.
            #expect(outsider.status == .notFound)
            #expect(wrongParent.status == .badRequest)
        }

        @Test
        func `Concurrent replies to the same parent both remain in the conversation`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()

            // Act.
            async let first = application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                note: "First branch",
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            async let second = application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                note: "Second branch",
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            let replies = try await [first, second]
            let result = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            // Assert.
            #expect(result.total == 3)
            #expect(Set(result.data.map(\.id)) == Set(replies.map(\.id) + [fixture.message.id]))
            #expect(replies.allSatisfy { $0.status?.replyToStatusId == fixture.message.id })
        }

        @Test
        func `Anonymous request is rejected`() async throws {

            // Arrange.
            let path = "/direct-messages/123/statuses"

            // Act.
            let response = try await application.sendRequest(
                to: path,
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: ["123"], note: "Hello"))

            // Assert.
            #expect(response.status == .unauthorized)
        }

        @Test
        func `Every reply notifies its explicit audience without repeating previous deliveries`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()

            // Act.
            let first = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.outsider],
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            let second = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.outsider],
                conversationId: fixture.message.conversationId,
                replyToStatusId: first.id)

            let notifications = try await Notification.query(on: application.db)
                .filter(\.$byUser.$id == fixture.recipient.requireID())
                .all()

            // Assert.
            #expect(notifications.count == 2)
            #expect(notifications.allSatisfy { $0.notificationType == .directMessage && $0.$user.id == fixture.outsider.id })
            #expect(Set(notifications.compactMap { $0.$status.id }) == Set([try requireDirectMessageId(first.id), try requireDirectMessageId(second.id)]))
        }
    }
}
