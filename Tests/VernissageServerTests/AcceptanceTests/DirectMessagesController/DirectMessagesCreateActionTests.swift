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
    @Suite("DirectMessages (POST /direct-messages)", .serialized, .tags(.directMessages))
    struct DirectMessagesCreateActionTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test(arguments: [false, true])
        func `A recipient blocking a participant is excluded without blocking other recipients`(blocksAuthor: Bool) async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let excluded = try await application.createDirectMessageUser()
            let allowed = try await application.createDirectMessageUser()
            _ = try await application.createUserBlockedUser(userId: excluded.requireID(),
                blockedUserId: (blocksAuthor ? author : allowed).requireID(), reason: "Blocked")

            // Act.
            let message = try await application.sendDirectMessage(
                author: author,
                recipients: [excluded, allowed])

            // Assert.
            #expect(message.recipients.map(\.id) == [allowed.stringId()!])
            #expect(try await UserDirectConversation.query(on: application.db).filter(\.$user.$id == excluded.requireID()).count() == 0)
            #expect(try await Notification.query(on: application.db).filter(\.$user.$id == excluded.requireID()).count() == 0)
            #expect(try await UserDirectConversation.query(on: application.db).filter(\.$user.$id == allowed.requireID()).count() == 1)
            #expect(try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .filter(\.$user.$id == excluded.requireID()).count() == 0)
        }

        @Test
        func `Every recipient is evaluated against the original group audience`() async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let first = try await application.createDirectMessageUser()
            let second = try await application.createDirectMessageUser()
            let third = try await application.createDirectMessageUser()
            _ = try await application.createUserBlockedUser(userId: first.requireID(), blockedUserId: second.requireID(), reason: "Blocked")
            _ = try await application.createUserBlockedUser(userId: second.requireID(), blockedUserId: third.requireID(), reason: "Blocked")

            // Act.
            let message = try await application.sendDirectMessage(
                author: author,
                recipients: [first, second, third])

            // Assert.
            #expect(message.recipients.map(\.id) == [third.stringId()!])
            #expect(try await UserDirectConversation.query(on: application.db).filter(\.$user.$id ~~ [first.requireID(), second.requireID()]).count() == 0)
        }

        @Test
        func `Excluding every local group recipient rolls back the new conversation`() async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let first = try await application.createDirectMessageUser()
            let second = try await application.createDirectMessageUser()
            _ = try await application.createUserBlockedUser(userId: first.requireID(), blockedUserId: second.requireID(), reason: "Blocked")
            _ = try await application.createUserBlockedUser(userId: second.requireID(), blockedUserId: first.requireID(), reason: "Blocked")
            let conversationCount = try await DirectConversation.query(on: application.db).count()

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: author.userName, password: "p@ssword"),
                to: "/direct-messages",
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: [first.stringId()!, second.stringId()!], note: "No eligible recipient"))

            // Assert.
            #expect(response.status == .forbidden)
            #expect(try await DirectConversation.query(on: application.db).count() == conversationCount)
            #expect(try await Status.query(on: application.db).filter(\.$user.$id == author.requireID()).count() == 0)
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$user.$id ~~ [author.requireID(), first.requireID(), second.requireID()]).count() == 0)
        }

        @Test
        func `Private Create sends signed text only to explicit personal inboxes and retries failed delivery`() async throws {
            // Arrange.
            let sender = try await application.createUser(userName: "sender" + UUID().uuidString, generateKeys: true)
            let local = try await application.createDirectMessageUser()
            let first = try await application.createDirectMessageUser(isLocal: false)
            let second = try await application.createDirectMessageUser(isLocal: false)
            let outsider = try await application.createDirectMessageUser(isLocal: false)
            _ = try await application.createFollow(sourceId: outsider.requireID(), targetId: sender.requireID(), approved: true)
            let failedInbox = try #require(second.userInbox)
            let session = DirectMessageDeliveryURLProtocol.session(failOnce: [failedInbox])

            defer { session.invalidateAndCancel() }
            let originalService = application.services.activityPubOutgoingStatusService
            application.services.activityPubOutgoingStatusService = ActivityPubOutgoingStatusService(urlSession: session)

            defer { application.services.activityPubOutgoingStatusService = originalService }
            let context = application.getQueueContext(queueName: .apStatus)

            // Act.
            let message = try await application.sendDirectMessage(
                author: sender,
                recipients: [first, first, second, local],
                note: "Private <text>")

            let event = try #require(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .first())
            let payload = ActivityPubStatusJobDataDto(statusActivityPubEventId: try event.requireID())

            await #expect(throws: Abort.self) {
                try await ActivityPubStatusJob().dequeue(context, payload)
            }

            try await ActivityPubStatusJob().dequeue(context, payload)
            let requests = DirectMessageDeliveryURLProtocol.requests
            let finished = try #require(try await StatusActivityPubEvent.find(event.id, on: application.db))

            // Assert.
            #expect(requests.count == 3)
            #expect(requests.filter { $0.url?.absoluteString == first.userInbox }.count == 1)
            #expect(requests.filter { $0.url?.absoluteString == failedInbox }.count == 2)
            #expect(finished.result == .finished)
            #expect(finished.attempts == 2)
            #expect(finished.eventContext == nil)

            for request in requests {
                let activity = try JSONDecoder().decode(ActivityDto.self, from: #require(request.httpBody))
                let object = try #require(activity.object.objects().first?.object as? NoteDto)
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "Signature")?.contains(sender.activityPubProfile + "#main-key") == true)
                #expect(request.value(forHTTPHeaderField: "Digest") != nil)
                #expect(activity.type == .create)
                #expect(activity.id == message.status?.activityPubId.appending("/activity"))
                #expect(Set(activity.to?.actorIds() ?? []) == Set([first.activityPubProfile, second.activityPubProfile, local.activityPubProfile]))
                #expect(activity.cc?.actorIds().isEmpty == true)
                #expect(object.to?.actorIds() == activity.to?.actorIds())
                #expect(object.cc?.actorIds() == activity.cc?.actorIds())
                #expect(object.content?.contains("Private &lt;text&gt;") == true)
                #expect(object.attachment?.isEmpty == true)
                #expect(object.tag?.tags().filter { $0.type == "Mention" }.count == 3)
                #expect(String(decoding: try #require(request.httpBody), as: UTF8.self).contains("activitystreams#Public") == false)
            }
        }

        @Test
        func `Attachment-only private Create includes image and local-only messages do not enqueue federation`() async throws {
            // Arrange.
            let sender = try await application.createUser(userName: "sender" + UUID().uuidString, generateKeys: true)
            let remote = try await application.createDirectMessageUser(isLocal: false)
            let local = try await application.createDirectMessageUser()
            let attachment = try await application.createAttachment(user: sender)

            defer { application.clearFiles(attachments: [attachment]) }
            let session = DirectMessageDeliveryURLProtocol.session()

            defer { session.invalidateAndCancel() }
            let previous = application.services.activityPubOutgoingStatusService
            application.services.activityPubOutgoingStatusService = ActivityPubOutgoingStatusService(urlSession: session)

            defer { application.services.activityPubOutgoingStatusService = previous }

            // Act.
            let message = try await application.sendDirectMessage(
                author: sender,
                recipients: [remote],
                note: "",
                attachmentIds: [try #require(attachment.stringId())])

            let localMessage = try await application.sendDirectMessage(
                author: sender,
                recipients: [local])

            let event = try #require(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .first())
            try await ActivityPubStatusJob().dequeue(application.getQueueContext(queueName: .apStatus),
                ActivityPubStatusJobDataDto(statusActivityPubEventId: event.requireID()))
            let request = try #require(DirectMessageDeliveryURLProtocol.requests.first)
            let activity = try JSONDecoder().decode(ActivityDto.self, from: #require(request.httpBody))

            // Assert.
            #expect((activity.object.objects().first?.object as? NoteDto)?.attachment?.count == 1)
            #expect(activity.to?.actorIds() == [remote.activityPubProfile])
            #expect(request.url?.absoluteString == remote.userInbox)
            #expect(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(localMessage.id))
                .count() == 0)
        }

        @Test
        func `Recipients sharing a personal inbox receive one delivery event item`() async throws {
            // Arrange.
            let sender = try await application.createDirectMessageUser()
            let first = try await application.createDirectMessageUser(isLocal: false)
            let second = try await application.createDirectMessageUser(isLocal: false)
            second.userInbox = first.userInbox
            try await second.save(on: application.db)

            // Act.
            let message = try await application.sendDirectMessage(
                author: sender,
                recipients: [first, second])

            let event = try #require(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .with(\.$statusActivityPubEventItems)
                .first())

            // Assert.
            #expect(event.statusActivityPubEventItems.count == 1)
            #expect(event.statusActivityPubEventItems.first?.url == first.userInbox)
            #expect(message.recipients.count == 2)
        }

        @Test
        func `Private delivery refuses an event item targeting an unrelated shared inbox`() async throws {
            // Arrange.
            let sender = try await application.createUser(userName: "sender" + UUID().uuidString, generateKeys: true)
            let remote = try await application.createDirectMessageUser(isLocal: false)
            let session = DirectMessageDeliveryURLProtocol.session()

            defer { session.invalidateAndCancel() }
            let previous = application.services.activityPubOutgoingStatusService
            application.services.activityPubOutgoingStatusService = ActivityPubOutgoingStatusService(urlSession: session)

            defer { application.services.activityPubOutgoingStatusService = previous }
            let message = try await application.sendDirectMessage(
                author: sender,
                recipients: [remote])

            let event = try #require(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .first())
            let item = StatusActivityPubEventItem(id: application.services.snowflakeService.generate(),
                statusActivityPubEventId: try event.requireID(), url: try #require(remote.sharedInbox))
            try await item.create(on: application.db)

            // Act.
            await #expect(throws: Abort.self) {
                try await ActivityPubStatusJob().dequeue(application.getQueueContext(queueName: .apStatus),
                    ActivityPubStatusJobDataDto(statusActivityPubEventId: event.requireID()))
            }

            let storedItem = try #require(try await StatusActivityPubEventItem.find(item.id, on: application.db))

            // Assert.
            #expect(DirectMessageDeliveryURLProtocol.requests.count == 1)
            #expect(DirectMessageDeliveryURLProtocol.requests.first?.url?.absoluteString == remote.userInbox)
            #expect(storedItem.isSuccess == false)
            #expect(storedItem.errorMessage == "Destination is not an explicit direct-message recipient inbox.")
        }

        @Test
        func `Missing personal inbox rolls back message and attachment reservation`() async throws {
            // Arrange.
            let sender = try await application.createDirectMessageUser()
            let remote = try await application.createDirectMessageUser(isLocal: false)
            remote.userInbox = nil
            try await remote.save(on: application.db)
            let attachment = try await application.createAttachment(user: sender)

            defer { application.clearFiles(attachments: [attachment]) }

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: sender.userName, password: "p@ssword"),
                to: "/direct-messages",
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: [try #require(remote.stringId())], note: "Hello",
                                              attachmentIds: [try #require(attachment.stringId())]))

            // Assert.
            #expect(response.status == .forbidden)
            #expect(try await Status.query(on: application.db).filter(\.$user.$id == sender.requireID()).count() == 0)
            #expect(try await StatusActivityPubEvent.query(on: application.db).filter(\.$user.$id == sender.requireID()).count() == 0)
            #expect(try await UserDirectConversation.query(on: application.db).filter(\.$user.$id == sender.requireID()).count() == 0)
            #expect(try await Attachment.find(attachment.id, on: application.db)?.$status.id == nil)
        }

        @Test
        func `Text message creates sender and local recipient inboxes without timelines or public counters`() async throws {

            // Arrange.
            let sender = try await application.createDirectMessageUser()
            let local = try await application.createDirectMessageUser()
            let remote = try await application.createDirectMessageUser(isLocal: false)

            // Act.
            let message = try await application.sendDirectMessage(
                author: sender,
                recipients: [local, local, remote],
                note: "Text only")

            let refreshed = try #require(try await User.find(sender.id, on: application.db))

            // Assert.
            #expect(message.status?.visibility == .mentioned)
            #expect(message.recipients.count == 2)
            #expect(message.status?.attachments?.isEmpty == true)
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == (try requireDirectMessageId(message.conversationId)))
                .count() == 2)
            #expect(try await UserStatus.query(on: application.db)
                .filter(\.$status.$id == (try requireDirectMessageId(message.id)))
                .count() == 0)
            let event = try #require(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == (try requireDirectMessageId(message.id)))
                .with(\.$statusActivityPubEventItems)
                .first())
            #expect(event.type == .create)
            #expect(event.result == .waiting)
            #expect(event.statusActivityPubEventItems.map(\.url) == [remote.userInbox])
            #expect(refreshed.statusesCount == sender.statusesCount)
        }

        @Test(arguments: [("🇵🇱", 100), ("👨‍👩‍👧‍👦", 28)])
        func `Combined emoji preview fits the database limit without changing message content`(emoji: String, previewCount: Int) async throws {
            // Arrange.
            let sender = try await application.createDirectMessageUser()
            let receiver = try await application.createDirectMessageUser()
            let note = String(repeating: emoji, count: 110)

            // Act.
            let message = try await application.sendDirectMessage(
                author: sender,
                recipients: [receiver],
                note: note)

            let inbox = try await application.getResponse(
                as: .user(userName: receiver.userName, password: "p@ssword"),
                to: "/direct-messages/\(message.conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            let status = try #require(try await Status.find(requireDirectMessageId(message.id), on: application.db))
            let summary = try #require(inbox.summary)

            // Assert.
            #expect(summary == String(repeating: emoji, count: previewCount))
            #expect(summary.unicodeScalars.count <= 200)
            #expect(status.note == note)
        }

        @Test
        func `Owned attachment can be sent without text and cannot be reused`() async throws {

            // Arrange.
            let sender = try await application.createDirectMessageUser()
            let receiver = try await application.createDirectMessageUser()
            let attachment = try await application.createAttachment(user: sender)

            defer { application.clearFiles(attachments: [attachment]) }
            let attachmentId = try attachment.requireID()

            // Act.
            let message = try await application.sendDirectMessage(
                author: sender,
                recipients: [receiver],
                note: "",
                attachmentIds: [String(attachmentId)])

            let inbox = try await application.getResponse(
                as: .user(userName: receiver.userName, password: "p@ssword"),
                to: "/direct-messages/\(message.conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            let reuse = try await application.sendRequest(
                as: .user(userName: sender.userName, password: "p@ssword"),
                to: "/direct-messages",
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: [receiver.stringId()!], attachmentIds: [String(attachmentId)]))

            // Assert.
            #expect(message.status?.attachments?.count == 1)
            #expect(inbox.summary == "Image")
            #expect(reuse.status == .notFound)
        }

        @Test
        func `Validation and blocked recipients leave no partial conversation`() async throws {

            // Arrange.
            let sender = try await application.createDirectMessageUser()
            let receiver = try await application.createDirectMessageUser()

            // Act.
            let empty = try await application.sendRequest(
                as: .user(userName: sender.userName, password: "p@ssword"),
                to: "/direct-messages",
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: [receiver.stringId()!], note: "  "))

            let ownAudience = try await application.sendRequest(
                as: .user(userName: sender.userName, password: "p@ssword"),
                to: "/direct-messages",
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: [sender.stringId()!], note: "Hello"))

            _ = try await application.createUserBlockedUser(userId: receiver.requireID(), blockedUserId: sender.requireID(), reason: "Blocked")
            let blocked = try await application.sendRequest(
                as: .user(userName: sender.userName, password: "p@ssword"),
                to: "/direct-messages",
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: [receiver.stringId()!], note: "Hello"))

            // Assert.
            #expect(empty.status == .badRequest)
            #expect(ownAudience.status == .badRequest)
            #expect(blocked.status == .forbidden)
            #expect(try await UserDirectConversation.query(on: application.db)
                .filter(\.$user.$id == sender.requireID())
                .count() == 0)

            // Other acceptance tests share the database; assert only this author's absence.
            #expect(try await Status.query(on: application.db)
                .filter(\.$user.$id == sender.requireID())
                .count() == 0)
        }

        @Test
        func `Foreign attachments are rejected and preview is bounded`() async throws {

            // Arrange.
            let sender = try await application.createDirectMessageUser()
            let receiver = try await application.createDirectMessageUser()
            let attachment = try await application.createAttachment(user: receiver)

            defer { application.clearFiles(attachments: [attachment]) }

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: sender.userName, password: "p@ssword"),
                to: "/direct-messages",
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: [receiver.stringId()!], note: "Hello", attachmentIds: [attachment.stringId()!]))

            let message = try await application.sendDirectMessage(
                author: sender,
                recipients: [receiver],
                note: String(repeating: "🙂", count: 220))

            let details = try await application.getResponse(
                as: .user(userName: receiver.userName, password: "p@ssword"),
                to: "/direct-messages/\(message.conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            // Assert.
            #expect(response.status == .notFound)
            #expect(details.summary?.count == 200)
        }

        @Test
        func `Photo status endpoint cannot change a direct message to a public status`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()

            // Act.
            let update = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)",
                method: .PUT,
                body: StatusRequestDto(note: "Public", visibility: .public, sensitive: false, contentWarning: nil,
                                       commentsDisabled: false, categoryId: nil, replyToStatusId: nil, attachmentIds: []))

            let status = try #require(try await Status.find(try requireDirectMessageId(fixture.message.id), on: application.db))

            // Assert.
            #expect(update.status == .forbidden)
            #expect(status.visibility == .mentioned)
        }

        @Test
        func `Anonymous request is rejected`() async throws {

            // Arrange.
            let path = "/direct-messages"

            // Act.
            let response = try await application.sendRequest(
                to: path,
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: ["123"], note: "Hello"))

            // Assert.
            #expect(response.status == .unauthorized)
        }

        @Test
        func `Direct message notifies only explicit local recipients`() async throws {
            // Arrange.
            let sender = try await application.createDirectMessageUser()
            let first = try await application.createDirectMessageUser()
            let second = try await application.createDirectMessageUser()
            let remote = try await application.createDirectMessageUser(isLocal: false)

            // Act.
            let message = try await application.sendDirectMessage(
                author: sender,
                recipients: [sender, first, first, second, remote],
                note: "Hello @someone@example.com")

            let notifications = try await Notification.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .all()

            // Assert.
            #expect(notifications.count == 2)
            #expect(notifications.allSatisfy { $0.notificationType == .directMessage })
            #expect(Set(notifications.map { $0.$user.id }) == Set([try first.requireID(), try second.requireID()]))
            #expect(notifications.allSatisfy { $0.$byUser.id == sender.id && $0.$mainStatus.id == nil })
        }

        @Test
        func `Notifications are persisted in the message transaction and pushed after commit`() async throws {
            // Arrange.
            let sender = try await application.createDirectMessageUser()
            let recipient = try await application.createDirectMessageUser()
            let original = application.services.notificationsService
            let recorder = DirectMessageNotificationRecorder()
            application.services.notificationsService = RecordingDirectMessageNotificationsService(base: original, recorder: recorder)

            defer { application.services.notificationsService = original }

            // Act.
            _ = try await application.sendDirectMessage(
                author: sender,
                recipients: [recipient])

            let snapshot = await recorder.snapshot()

            // Assert.
            #expect(snapshot.saved == [true])
            #expect(snapshot.dispatched == [false])
        }

        @Test
        func `Failed notification persistence rolls back the message inbox and notification`() async throws {
            // Arrange.
            let sender = try await application.createDirectMessageUser()
            let recipient = try await application.createDirectMessageUser()
            let original = application.services.notificationsService
            let recorder = DirectMessageNotificationRecorder()
            application.services.notificationsService = RecordingDirectMessageNotificationsService(base: original, recorder: recorder, failAfterSave: true)

            defer { application.services.notificationsService = original }

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: sender.userName, password: "p@ssword"),
                to: "/direct-messages",
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: [recipient.stringId()!], note: "Hello"))

            let snapshot = await recorder.snapshot()

            // Assert.
            #expect(response.status == .internalServerError)
            #expect(snapshot.saved == [true])
            #expect(snapshot.dispatched.isEmpty)
            #expect(try await Status.query(on: application.db).filter(\.$user.$id == sender.requireID()).count() == 0)
            #expect(try await UserDirectConversation.query(on: application.db).filter(\.$user.$id == recipient.requireID()).count() == 0)
            #expect(try await Notification.query(on: application.db).filter(\.$user.$id == recipient.requireID()).count() == 0)
        }

        @Test
        func `Prepared incoming direct message creates one notification even when delivered again`() async throws {
            // Arrange.
            let sender = try await application.createDirectMessageUser(isLocal: false)
            let recipient = try await application.createDirectMessageUser()
            let original = application.services.notificationsService
            let recorder = DirectMessageNotificationRecorder()
            application.services.notificationsService = RecordingDirectMessageNotificationsService(base: original, recorder: recorder)

            defer { application.services.notificationsService = original }
            let request = Request(application: application, on: application.eventLoopGroup.next())
            let status = Status(id: application.services.snowflakeService.generate(), isLocal: false,
                                userId: try sender.requireID(), note: "Incoming message",
                                baseAddress: "https://remote.example", userName: sender.userName,
                                application: nil, categoryId: nil, visibility: .mentioned, publishedAt: Date())

            // Act.
            let stored = try await application.services.activityPubDirectMessagesService.store(status: status,
                recipientIds: [recipient.requireID()], conversationId: nil, on: request.executionContext)
            let conversationId = try #require(stored.$directConversation.id)
            _ = try await application.sendRequest(
                as: .user(userName: recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(conversationId)/read",
                method: .POST,
                body: DirectConversationReadRequestDto(statusIds: [String(try stored.requireID())]))

            _ = try await application.services.activityPubDirectMessagesService.store(status: status,
                recipientIds: [recipient.requireID()], conversationId: nil, on: request.executionContext)
            let snapshot = await recorder.snapshot()
            let details = try await application.getResponse(
                as: .user(userName: recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            // Assert.
            #expect(snapshot.saved == [true])
            #expect(snapshot.dispatched == [false])
            #expect(details.hasUnreadMessages == false)
            #expect(try await Notification.query(on: application.db).filter(\.$status.$id == stored.requireID()).count() == 1)
        }
    }
}
