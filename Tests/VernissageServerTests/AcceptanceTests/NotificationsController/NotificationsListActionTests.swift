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
    
    @Suite("Notifications (GET /notifications)", .serialized, .tags(.notifications))
    struct NotificationsListActionTests {
        var application: Application!
        
        init() async throws {
            self.application = try await ApplicationManager.shared.application()
        }
        
        @Test
        func `Notifications list should be returned for authorized user`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "carinroki")
            let user2 = try await application.createUser(userName: "adamroki")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Notifications List", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            try await application.favouriteStatus(user: user2, status: statuses.first!)
            
            // Act.
            let notifications = try await application.getResponse(
                as: .user(userName: "carinroki", password: "p@ssword"),
                to: "/notifications",
                method: .GET,
                decodeTo: LinkableResultDto<NotificationDto>.self
            )
            
            // Assert.
            #expect(notifications.data.count > 0, "Notifications list should be returned.")
            #expect(notifications.data.first?.createdAt != nil, "Date of the notification should be returned")
        }
        
        @Test
        func `Notifications list should be returned with main status for comments`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "mariaroki")
            let user2 = try await application.createUser(userName: "monikaroki")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Notifications List", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }
            
            let comment = try await application.createStatus(user: user2, note: "Super comment", attachmentIds: [], replyToStatusId: statuses.first?.stringId())
            try await application.favouriteStatus(user: user1, status: comment)
            
            // Act.
            let notifications = try await application.getResponse(
                as: .user(userName: "monikaroki", password: "p@ssword"),
                to: "/notifications",
                method: .GET,
                decodeTo: LinkableResultDto<NotificationDto>.self
            )
            
            // Assert.
            #expect(notifications.data.count > 0, "Notifications list should be returned.")
            #expect(notifications.data.first?.mainStatus != nil, "Notification should contain main status.")
            #expect(notifications.data.first?.mainStatus?.id == statuses.first?.stringId(), "Notification should containt correct main status.")
        }

        @Test
        func `Notifications list should not return notifications created by deleted users`() async throws {
            // Arrange.
            let user1 = try await application.createUser(userName: "ewaroki")
            let user2 = try await application.createUser(userName: "janroki")
            let (statuses, attachments) = try await application.createStatuses(user: user1, notePrefix: "Note Notifications Deleted User", amount: 1)
            defer {
                application.clearFiles(attachments: attachments)
            }

            try await application.favouriteStatus(user: user2, status: try #require(statuses.first))
            try await user2.delete(on: application.db)

            // Act.
            let notifications = try await application.getResponse(
                as: .user(userName: "ewaroki", password: "p@ssword"),
                to: "/notifications",
                method: .GET,
                decodeTo: LinkableResultDto<NotificationDto>.self
            )

            // Assert.
            #expect(notifications.data.isEmpty, "Notifications created by deleted users should not be returned.")
        }
        
        @Test
        func `Notifications list should not be returned for unauthorized user`() async throws {
            
            // Act.
            let response = try await application.sendRequest(
                to: "/notifications",
                method: .GET
            )
            
            // Assert.
            #expect(response.status == HTTPResponseStatus.unauthorized, "Response http status code should be unauthorized (401).")
        }

        @Test
        func `Direct message notifications contain the destination conversation and accessible message`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()

            // Act.
            let result = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/notifications",
                method: .GET,
                decodeTo: LinkableResultDto<NotificationDto>.self)

            let outsider = try await application.getResponse(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/notifications",
                method: .GET,
                decodeTo: LinkableResultDto<NotificationDto>.self)

            // Assert.
            #expect(result.data.count == 1)
            #expect(result.data.first?.notificationType == .directMessage)
            #expect(result.data.first?.conversationId == fixture.message.conversationId)
            #expect(result.data.first?.status?.id == fixture.message.id)
            #expect(result.data.first?.mainStatus == nil)
            #expect(outsider.data.isEmpty)
        }

        @Test
        func `Favourite of a direct reply includes its conversation without exposing the hidden root`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let limited = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.outsider],
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            let reply = try await application.sendDirectMessage(
                author: fixture.outsider,
                recipients: [fixture.recipient],
                conversationId: fixture.message.conversationId,
                replyToStatusId: limited.id)

            _ = try await application.sendRequest(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/statuses/\(reply.id)/favourite",
                method: .POST)

            // Act.
            _ = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/statuses/\(reply.id)/favourite",
                method: .POST)

            let result = try await application.getResponse(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/notifications",
                method: .GET,
                decodeTo: LinkableResultDto<NotificationDto>.self)

            let favourites = result.data.filter { $0.notificationType == .favourite }
            let stored = try #require(try await Notification.query(on: application.db)
                .filter(\.$notificationType == .favourite)
                .filter(\.$status.$id == requireDirectMessageId(reply.id))
                .first())

            // Assert.
            #expect(favourites.count == 1)
            #expect(favourites.first?.conversationId == fixture.message.conversationId)
            #expect(favourites.first?.status?.id == reply.id)
            #expect(favourites.first?.mainStatus == nil)
            #expect(stored.$mainStatus.id == nil)
            #expect(favourites.first?.byUser.id == fixture.recipient.stringId())
        }
    }
}
