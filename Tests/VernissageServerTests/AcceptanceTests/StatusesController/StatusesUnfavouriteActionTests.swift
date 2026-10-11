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
    
    @Suite("Statuses (POST /statuses/:id/unfavourite)", .serialized, .tags(.statuses))
    struct StatusesUnfavouriteActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Remote private unfavourite sends Undo with the original Like id only to the author`() async throws {
            // Arrange.
            let remote = try await application.createRemoteDirectMessageUser()
            let local = try await application.createUser(userName: "dmundo" + UUID().uuidString, generateKeys: true)
            let note = privateActivityPubNote(sender: remote, recipients: [local])
            _ = try await application.receivePrivateActivityPubNote(note, sender: remote)
            let status = try #require(try await Status.query(on: application.db)
                .filter(\.$activityPubId == note.id)
                .first())
            _ = try await application.sendRequest(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/statuses/\(status.requireID())/favourite",
                method: .POST)

            let favourite = try #require(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .filter(\.$user.$id == local.requireID())
                .first())
            let context = application.getQueueContext(queueName: .apStatus)

            try await StatusFavouriterJob().dequeue(context, favourite.requireID())
            let pendingLike = try #require(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .filter(\.$type == .like)
                .first())
            let session = DirectMessageDeliveryURLProtocol.session()

            defer { session.invalidateAndCancel() }
            let previous = application.services.activityPubOutgoingStatusService
            application.services.activityPubOutgoingStatusService = ActivityPubOutgoingStatusService(urlSession: session)

            defer { application.services.activityPubOutgoingStatusService = previous }

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: local.userName, password: "p@ssword"),
                to: "/statuses/\(status.requireID())/unfavourite",
                method: .POST)

            let undoPayload = StatusUnfavouriteJobDto(statusFavouriteId: try #require(favourite.stringId()),
                userId: try local.requireID(), statusId: try status.requireID())
            try await StatusUnfavouriterJob().dequeue(context, undoPayload)
            let event = try #require(try await StatusActivityPubEvent.query(on: application.db)
                .filter(\.$status.$id == status.requireID())
                .filter(\.$type == .unlike)
                .first())
            try await ActivityPubStatusJob().dequeue(context,
                ActivityPubStatusJobDataDto(statusActivityPubEventId: event.requireID(), statusFavouriteId: favourite.stringId()))

            // A queued Like processed after Undo must not resurrect the user's old reaction.
            try await ActivityPubStatusJob().dequeue(context,
                ActivityPubStatusJobDataDto(statusActivityPubEventId: pendingLike.requireID(), statusFavouriteId: favourite.stringId()))
            let request = try #require(DirectMessageDeliveryURLProtocol.requests.first)
            let activity = try JSONDecoder().decode(ActivityDto.self, from: #require(request.httpBody))
            let nested = try #require(activity.object.objects().first?.object as? LikeDto)

            // Assert.
            #expect(response.status == .ok)
            #expect(DirectMessageDeliveryURLProtocol.requests.count == 1)
            #expect(request.url?.absoluteString == remote.userInbox)
            #expect(activity.type == .undo)
            #expect(activity.to?.actorIds() == [remote.activityPubProfile])
            #expect(nested.to?.actorIds() == [remote.activityPubProfile])
            #expect(nested.actor?.actorIds() == [local.activityPubProfile])
            #expect(nested.id == local.activityPubProfile + "#likes/" + (try #require(favourite.stringId())))
            #expect(nested.object?.objects().first?.id == status.activityPubId)
            #expect(request.value(forHTTPHeaderField: "Signature")?.contains(local.activityPubProfile + "#main-key") == true)
        }
        
        @Test
        func `Status should be unfavourited for authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "carinmina")
            let user2 = try await application.createUser(userName: "adammina")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfavorited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            try await application.favouriteStatus(user: user2, status: statuses.first!)
            
            // Act.
            let statusDto = try await application.getResponse(
                as: .user(userName: "adammina", password: "p@ssword"),
                to: "/statuses/\(statuses.first!.requireID())/unfavourite",
                method: .POST,
                decodeTo: StatusDto.self
            )
            
            // Assert.
            #expect(statusDto.id != nil, "Status wasn't created.")
            #expect(statusDto.favourited == false, "Status should be marked as unfavourited.")
            #expect(statusDto.favouritesCount == 0, "Favourited count should be equal 0.")
            
            let notification = try await application.getNotification(type: .favourite, to: user1.requireID(), by: user2.requireID(), statusId: statusDto.id?.toId())
            #expect(notification == nil, "Notification should be deleted.")
        }
        
        @Test
        func `Not found should be returned if status not exists`() async throws {
            
            // Arrange.
            _ = try await application.createUser(userName: "maxmina")
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                as: .user(userName: "maxmina", password: "p@ssword"),
                to: "/statuses/123456789/unfavourite",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
        }
        
        @Test
        func `Unauthorized should be returned for not authorized user`() async throws {
            
            // Arrange.
            let user1 = try await application.createUser(userName: "moiquemina")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Unfavorited", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/statuses/\(statuses.first!.requireID())/unfavourite",
                method: .POST
            )
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }

        @Test
        func `Direct message unfavourite removes the reaction and notification without marking the message read`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            _ = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)/favourite",
                method: .POST)

            let before = try #require(try await UserDirectConversation.query(on: application.db)
                .filter(\.$conversation.$id == requireDirectMessageId(fixture.message.conversationId))
                .filter(\.$user.$id == fixture.recipient.requireID())
                .first())

            // Act.
            let unliked = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)/unfavourite",
                method: .POST,
                decodeTo: StatusDto.self)

            let repeated = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)/unfavourite",
                method: .POST,
                decodeTo: StatusDto.self)

            let messages = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            let after = try #require(try await UserDirectConversation.find(before.id, on: application.db))

            // Assert.
            #expect(unliked.favourited == false)
            #expect(repeated.favouritesCount == 0)
            #expect(messages.data.first?.status?.favourited == false)
            #expect(messages.data.first?.status?.favouritesCount == 0)
            #expect(messages.data.first?.readAt == nil)
            #expect(after.lastActivityAt == before.lastActivityAt)
            #expect(after.lastReadAt == before.lastReadAt)
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(fixture.message.id))
                .count() == 0)
            #expect(try await Notification.query(on: application.db)
                .filter(\.$notificationType == .favourite)
                .filter(\.$status.$id == requireDirectMessageId(fixture.message.id))
                .count() == 0)
        }

        @Test
        func `Inbox member cannot unfavourite a message outside their explicit audience`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let limited = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.outsider],
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            _ = try await application.sendRequest(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/statuses/\(limited.id)/favourite",
                method: .POST)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/statuses/\(limited.id)/unfavourite",
                method: .POST)

            // Assert.
            #expect(response.status == .forbidden)
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(limited.id))
                .count() == 1)
        }
    }
}
