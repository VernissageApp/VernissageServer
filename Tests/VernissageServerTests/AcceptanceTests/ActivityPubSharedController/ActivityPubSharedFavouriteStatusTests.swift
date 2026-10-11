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

extension ControllersTests {
    
    @Suite("ActivityPubShared (POST /shared/inbox [FavouriteStatus])", .serialized, .tags(.shared))
    struct ActivityPubSharedFavouriteStatusTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }

        @Test(arguments: [false, true])
        func `Private Like respects mute and never exposes an inaccessible ancestor`(muted: Bool) async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let local = try await application.createDirectMessageUser()
            let remote = try await application.createRemoteDirectMessageUser()
            let root = try await application.sendDirectMessage(
                author: author,
                recipients: [local])

            let reply = try await application.sendDirectMessage(
                author: author,
                recipients: [remote],
                conversationId: root.conversationId,
                replyToStatusId: root.id)

            let statusId = try requireDirectMessageId(reply.id)

            if muted {
                _ = try await application.sendRequest(
                    as: .user(userName: author.userName, password: "p@ssword"),
                    to: "/direct-messages/\(root.conversationId)/mute",
                    method: .PUT,
                    body: DirectConversationMuteRequestDto(isMuted: true))

            }

            let initial = try #require(try await UserDirectConversation.query(on: application.db)
                .filter(\.$user.$id == author.requireID())
                .filter(\.$conversation.$id == requireDirectMessageId(root.conversationId))
                .first())

            // Act.
            let response = try await application.receivePrivateLike(statusActivityPubId: try #require(reply.status?.activityPubId), sender: remote)
            let notifications = try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == statusId)
                .filter(\.$notificationType == .favourite)
                .all()

            let inbox = try #require(try await UserDirectConversation.find(initial.id, on: application.db))

            // Assert.
            #expect(response.status == .ok)
            #expect(try await Status.find(statusId, on: application.db)?.favouritesCount == 1)
            #expect(notifications.count == (muted ? 0 : 1))
            #expect(notifications.allSatisfy { $0.$mainStatus.id == nil })
            #expect(inbox.lastActivityAt == initial.lastActivityAt)
            #expect(inbox.lastReadAt == initial.lastReadAt)
            #expect(try await StatusRecipient.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(root.id))
                .filter(\.$user.$id == remote.requireID())
                .count() == 0)
        }

        @Test
        func `Conversation membership does not authorize liking an unaddressed message`() async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let remote = try await application.createRemoteDirectMessageUser()
            let local = try await application.createDirectMessageUser()
            let root = try await application.sendDirectMessage(
                author: author,
                recipients: [remote, local])

            let restricted = try await application.sendDirectMessage(
                author: author,
                recipients: [local],
                conversationId: root.conversationId)

            // Act.
            let response = try await application.receivePrivateLike(statusActivityPubId: try #require(restricted.status?.activityPubId), sender: remote)

            // Assert.
            #expect(response.status == .ok)
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(restricted.id))
                .count() == 0)
            #expect(try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(restricted.id))
                .filter(\.$notificationType == .favourite)
                .count() == 0)
        }

        @Test
        func `Concurrent private Like deliveries create one favourite and notification`() async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let remote = try await application.createRemoteDirectMessageUser()
            let message = try await application.sendDirectMessage(
                author: author,
                recipients: [remote])

            let objectId = try #require(message.status?.activityPubId)

            // Act.
            async let first = application.receivePrivateLike(statusActivityPubId: objectId, sender: remote)
            async let second = application.receivePrivateLike(statusActivityPubId: objectId, sender: remote,
                                                              inbox: "/actors/\(author.userName)/inbox")
            let responses = try await (first, second)

            // Assert.
            #expect(responses.0.status == .ok)
            #expect(responses.1.status == .ok)
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .count() == 1)
            #expect(try await VernissageServer.Notification.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .filter(\.$notificationType == .favourite)
                .count() == 1)
        }

        @Test(arguments: [false, true])
        func `Private Like is ignored when either participant blocks the other`(blockedByAuthor: Bool) async throws {
            // Arrange.
            let author = try await application.createDirectMessageUser()
            let remote = try await application.createRemoteDirectMessageUser()
            let message = try await application.sendDirectMessage(
                author: author,
                recipients: [remote])

            _ = try await application.createUserBlockedUser(userId: blockedByAuthor ? author.requireID() : remote.requireID(),
                blockedUserId: blockedByAuthor ? remote.requireID() : author.requireID(), reason: "Blocked")

            // Act.
            let response = try await application.receivePrivateLike(statusActivityPubId: try #require(message.status?.activityPubId), sender: remote)

            // Assert.
            #expect(response.status == .ok)
            #expect(try await StatusFavourite.query(on: application.db)
                .filter(\.$status.$id == requireDirectMessageId(message.id))
                .count() == 0)
        }
        
        @Test
        func `Status should be favourited when all correct data has been applied`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "vikiropix", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
                        
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            
            let likeTarget = ActivityPub.Notes.like("3412326",
                                                    user.activityPubProfile,
                                                    status.activityPubId,
                                                    user.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: likeTarget.headers?.getHTTPHeaders() ?? .init(),
                body: likeTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let statusFavouriteFromDatabase = try await application.getStatusFavourite(statusId: status.requireID())
            #expect(statusFavouriteFromDatabase != nil, "Status must be favourited in local datbase.")
        }
        
        @Test
        func `Comment should be favourited when all correct data has been applied`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "troporopix", generateKeys: true, isLocal: true)
            let user2 = try await application.createUser(userName: "mororopix", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user1)
            let status = try await application.createStatus(user: user1, note: "Tropo note 2", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let comment = try await application.createStatus(user: user1, note: "My comment to my status", attachmentIds: [], replyToStatusId: status.stringId())
            
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            
            let likeTarget = ActivityPub.Notes.like("3412324",
                                                    user2.activityPubProfile,
                                                    comment.activityPubId,
                                                    user2.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost")
            
            // Act.
            let response = try await application.sendRequest(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: likeTarget.headers?.getHTTPHeaders() ?? .init(),
                body: likeTarget.httpBody!)
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.ok, "Response http status code should be ok (200).")
            
            let statusFavouriteFromDatabase = try await application.getStatusFavourite(statusId: comment.requireID())
            #expect(statusFavouriteFromDatabase != nil, "Status must be favourited in local datbase.")
            
            let notification = try await application.getNotification(type: .favourite, to: user1.requireID(), by: user2.requireID(), statusId: comment.id)
            #expect(notification != nil, "Notification should be added.")
            #expect(notification?.$mainStatus.id != nil, "Notification should contain main status.")
        }
        
        @Test
        func `Status should not be favourited when date is outside time frame`() async throws {
            // Arrange.
            let user = try await application.createUser(userName: "marcinropix", generateKeys: true, isLocal: false)
            let attachment = try await application.createAttachment(user: user)
            let status = try await application.createStatus(user: user, note: "Note 1", attachmentIds: [attachment.stringId()!])
            defer {
                application.clearFiles(attachments: [attachment])
            }
            
            let createdStatus = try await Status.query(on: application.db).filter(\.$id == status.requireID()).first()
            createdStatus?.isLocal = false
            try await createdStatus?.save(on: application.db)
            
            let likeTarget = ActivityPub.Notes.like("3412324",
                                                    user.activityPubProfile,
                                                    status.activityPubId,
                                                    user.privateKey!,
                                                    "/shared/inbox",
                                                    Constants.userAgent,
                                                    "localhost")
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
            
            let dateString = dateFormatter.string(from: Date.now.addingTimeInterval(-600))
            
            var headers = likeTarget.headers?.getHTTPHeaders() ?? HTTPHeaders()
            headers.replaceOrAdd(name: "date", value: dateString)
            
            // Act.
            let errorResponse = try await application.getErrorResponse(
                to: "/shared/inbox",
                version: .none,
                method: .POST,
                headers: headers,
                body: likeTarget.httpBody!)
            
            // Assert.
            #expect(errorResponse.status == HTTPResponseStatus.badRequest, "Response http status code should be bad request (400).")
            #expect(errorResponse.error.code == "badTimeWindow", "Error code should be equal 'badTimeWindow'.")
            #expect(errorResponse.error.reason == "ActivityPub signed request date '\(dateString)' is outside acceptable time window.")
            
            let statusFavouriteFromDatabase = try await application.getStatusFavourite(statusId: status.requireID())
            #expect(statusFavouriteFromDatabase == nil, "Status must not be favourited in local datbase.")
        }
    }
}
