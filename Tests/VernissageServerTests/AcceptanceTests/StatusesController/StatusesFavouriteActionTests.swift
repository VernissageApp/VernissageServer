//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import ActivityPubKit
import Vapor
import Testing
import Fluent
import Queues

extension ControllersTests {
    
    @Suite("Statuses (POST /statuses/:id/favourite)", .serialized, .tags(.statuses))
    struct StatusesFavouriteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Remote private favourite is signed and delivered only to its author's personal inbox with retries`() async throws {
            // Arrange.
            let remote = try await application.createRemoteDirectMessageUser()
            let local = try await application.createUser(userName: "dmlike" + UUID().uuidString, generateKeys: true)
            let note = privateActivityPubNote(sender: remote, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(note, sender: remote)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())
            let inbox = try #require(remote.userInbox)
            let session = DirectMessageDeliveryURLProtocol.session(failOnce: [inbox])

            defer { session.invalidateAndCancel() }
            let previous = application.services.activityPubOutgoingStatusService
            application.services.activityPubOutgoingStatusService = ActivityPubOutgoingStatusService(urlSession: session)

            defer { application.services.activityPubOutgoingStatusService = previous }
            let context = application.getQueueContext(queueName: .apStatus)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/statuses/\(status.requireID())/favourite",
                method: .POST)

            let favourite = try #require(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .filter(\.$user.$id == local.requireID())
                .first())
            try await StatusFavouriterJob().dequeue(context, favourite.requireID())
            let event = try #require(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .filter(\.$type == .like)
                .with(\.$statusActivityPubEventItems)
                .first())
            let payload = ActivityPubStatusJobDataDto(statusActivityPubEventId: try event.requireID(), statusFavouriteId: favourite.stringId())

            await #expect(throws: Abort.self) { try await ActivityPubStatusJob().dequeue(context, payload) }
            try await ActivityPubStatusJob().dequeue(context, payload)
            let request = try #require(DirectMessageDeliveryURLProtocol.requests.first)
            let activity = try JSONDecoder().decode(ActivityDto.self, from: #require(request.httpBody))

            // Assert.
            #expect(response.status == .ok)
            #expect(event.statusActivityPubEventItems.map(\.url) == [inbox])
            #expect(DirectMessageDeliveryURLProtocol.requests.count == 2)
            #expect(DirectMessageDeliveryURLProtocol.requests.allSatisfy { $0.url?.absoluteString == inbox })
            #expect(activity.type == .like)
            #expect(activity.to?.actorIds() == [remote.activityPubProfile])
            #expect(activity.cc == nil)
            #expect(activity.actor.actorIds() == [local.activityPubProfile])
            #expect(activity.object.objects().first?.id == status.activityPubId)
            #expect(activity.id == local.activityPubProfile + "#likes/" + (try #require(favourite.stringId())))
            #expect(request.value(forHTTPHeaderField: "Signature")?.contains(local.activityPubProfile + "#main-key") == true)
            #expect(try await StatusActivityPubEvent.find(event.requireID(), on: application.db)?.result == .finished)
        }
        
        @Test
        func `Status should be favourited for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carintofi")
            let user2 = try await application.createUser(userName: "adamtofi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "adamtofi", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/favourite",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.favourited == true, "Status should be marked as favourited.")
            #expect(statusDto.favouritesCount == 1, "Favourited count should be equal 1.")
            
            let notification = try await application.getNotification(type: .favourite, to: user1.requireID(), by: user2.requireID(), statusId: statusDto.id?.toId())
            #expect(notification != nil, "Notification should be added.")
        }
        
        @Test
        func `Comment should be favourited for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "matistofi")
            let user2 = try await application.createUser(userName: "maliktofi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let comment = try await application.createStatus(user: user2, note: "Super comment", attachmentIds: [], replyToStatusId: statuses.first?.stringId())
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "matistofi", password: "p@ssword"),
                to: "/statuses/\(comment.requireID())/favourite",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.favourited == true, "Status should be marked as favourited.")
            #expect(statusDto.favouritesCount == 1, "Favourited count should be equal 1.")
            
            let notification = try await application.getNotification(type: .favourite, to: user2.requireID(), by: user1.requireID(), statusId: comment.id)
            #expect(notification != nil, "Notification should be added.")
            #expect(notification?.$mainStatus.id != nil, "Notification should contain main status.")
        }
        
        @Test
        func `Favouring own status should not add notification`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "jakobtofi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "jakobtofi", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/favourite",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.favourited == true, "Status should be marked as favourited.")
            #expect(statusDto.favouritesCount == 1, "Favourited count should be equal 1.")
            
            let notification = try await application.getNotification(type: .favourite, to: user1.requireID(), by: user1.requireID(), statusId: statusDto.id?.toId())
            #expect(notification == nil, "Notification should not be added.")
        }

        @Test
        func `Favouriting status should not add notification when actor is blocked`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "bettytofi")
            let user2 = try await application.createUser(userName: "taylortofi")
            _ = try await application.createUserBlockedUser(userId: user1.requireID(), blockedUserId: user2.requireID(), reason: "")

            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited Blocked", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }

            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: user2.userName, password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/favourite",
                method: .POST,
                decodeTo: StatusDto.self
            )

            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.favourited == true, "Status should be marked as favourited.")
            #expect(statusDto.favouritesCount == 1, "Favourited count should be equal 1.")
            
            let notification = try await application.getNotification(type: .favourite,
                                                                     to: user1.requireID(),
                                                                     by: user2.requireID(),
                                                                     statusId: statuses.first!.requireID())
            #expect(notification == nil, "Notification should not be added when actor is blocked.")
        }
        
        @Test
        func `Forbidden should be returned for status with mentioned visibility`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "brostofi")
            _ = try await application.createUser(userName: "ingatofi")
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createLegacyMentionedStatus(user: user1, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "ingatofi", password: "p@ssword"),
                to: "/statuses/\(status.requireID())/favourite",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
        }
        
        @Test
        func `Not found should be returned if status not exists`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxtofi")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxtofi", password: "p@ssword"),
                to: "/statuses/123456789/favourite",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiquetofi")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Favourited Unauthorized", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/favourite",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }

        @Test
        func `Direct message favourites are personal idempotent and do not change inbox state`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let before = try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == requireDirectMessageId(fixture.message.conversationId))
                .sort(\.$user.$id)
                .all()

            // Act.
            let liked = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)/favourite",
                method: .POST,
                decodeTo: StatusDto.self)

            let repeated = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)/favourite",
                method: .POST,
                decodeTo: StatusDto.self)

            let recipientMessages = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            let authorMessages = try await application.getResponse(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            let after = try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == requireDirectMessageId(fixture.message.conversationId))
                .sort(\.$user.$id)
                .all()

            // Assert.
            #expect(liked.favourited == true)
            #expect(repeated.favouritesCount == 1)
            #expect(recipientMessages.data.first?.status?.favourited == true)
            #expect(recipientMessages.data.first?.status?.favouritesCount == 1)
            #expect(recipientMessages.data.first?.readAt == nil)
            #expect(authorMessages.data.first?.status?.favourited == false)
            #expect(after.map(\.lastActivityAt) == before.map(\.lastActivityAt))
            #expect(after.map(\.lastReadAt) == before.map(\.lastReadAt))
            #expect(after.map(\.summary) == before.map(\.summary))
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(fixture.message.id))
                .count() == 1)
            #expect(try await Notification.query(on: application.db)
                .filter(\.$notificationType == .favourite)
                .filter(\.$status.$id == requireDirectMessageId(fixture.message.id))
                .count() == 1)
        }

        @Test
        func `Inbox membership does not allow favouriting a message addressed to other participants`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let limited = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.outsider],
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/statuses/\(limited.id)/favourite",
                method: .POST)

            // Assert.
            #expect(response.status == .forbidden)
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(limited.id))
                .count() == 0)
        }

        @Test
        func `Muted direct conversation suppresses favourite notifications until unmuted`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            _ = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/mute",
                method: .PUT,
                body: DirectConversationMuteRequestDto(isMuted: true))

            // Act.
            let liked = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)/favourite",
                method: .POST,
                decodeTo: StatusDto.self)

            let mutedCount = try await Notification.query(on: application.db)
                .filter(\.$notificationType == .favourite)
                .filter(\.$status.$id == requireDirectMessageId(fixture.message.id))
                .count()
            _ = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/mute",
                method: .PUT,
                body: DirectConversationMuteRequestDto(isMuted: false))

            _ = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)/unfavourite",
                method: .POST)

            _ = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)/favourite",
                method: .POST)

            let unmutedCount = try await Notification.query(on: application.db)
                .filter(\.$notificationType == .favourite)
                .filter(\.$status.$id == requireDirectMessageId(fixture.message.id))
                .count()

            // Assert.
            #expect(liked.favouritesCount == 1)
            #expect(mutedCount == 0)
            #expect(unmutedCount == 1)
        }
    }
}
