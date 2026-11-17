//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Testing
import Vapor

extension ControllersTests {
    @Suite("DirectMessages (POST /direct-messages/123/read)", .serialized, .tags(.directMessages))
    struct DirectMessagesMarkReadActionTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test
        func `A displayed selection can include a deleted message`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let live = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                conversationId: fixture.message.conversationId)

            _ = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)",
                method: .DELETE)

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/read",
                method: .POST,
                body: DirectConversationReadRequestDto(statusIds: [fixture.message.id, live.id]))

            let messages = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            // Assert.
            #expect(response.status == .noContent)
            #expect(messages.data.first { $0.id == live.id }?.readAt != nil)
            #expect(messages.data.first { $0.id == fixture.message.id }?.deletedAt != nil)
        }

        @Test
        func `Selected messages are read idempotently and new messages remain unread`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let second = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                conversationId: fixture.message.conversationId)

            let path = "/direct-messages/\(fixture.message.conversationId)/read"

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: path,
                method: .POST,
                body: DirectConversationReadRequestDto(statusIds: [fixture.message.id]))

            let read = try #require(try await StatusRecipient.query(on: application.db)
                .filter(\.$user.$id == fixture.recipient.requireID())
                .filter(\.$status.$id == (try requireDirectMessageId(fixture.message.id)))
                .first())

            _ = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: path,
                method: .POST,
                body: DirectConversationReadRequestDto(statusIds: [fixture.message.id]))

            let repeated = try #require(try await StatusRecipient.find(read.id, on: application.db))
            let details = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            _ = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: path,
                method: .POST,
                body: DirectConversationReadRequestDto(statusIds: [second.id]))

            let count = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/unread-count",
                method: .GET,
                decodeTo: DirectConversationsUnreadCountDto.self)

            // Assert.
            #expect(response.status == .noContent)
            #expect(read.readAt != nil)
            #expect(repeated.readAt == read.readAt)
            #expect(details.hasUnreadMessages)
            #expect(details.lastStatusId == second.id)
            #expect(count.count == 0)
        }

        @Test
        func `Read selection cannot include messages from another conversation`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let other = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient])

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/read",
                method: .POST,
                body: DirectConversationReadRequestDto(statusIds: [fixture.message.id, other.id]))

            let recipient = try #require(try await StatusRecipient.query(on: application.db)
                .filter(\.$user.$id == fixture.recipient.requireID())
                .filter(\.$status.$id == (try requireDirectMessageId(fixture.message.id)))
                .first())

            let foreign = try await application.sendRequest(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/read",
                method: .POST,
                body: DirectConversationReadRequestDto(statusIds: [fixture.message.id]))

            // Assert.
            #expect(response.status == .badRequest)
            #expect(recipient.readAt == nil)
            #expect(foreign.status == .notFound)
        }

        @Test
        func `Anonymous request is rejected`() async throws {

            // Arrange.
            let path = "/direct-messages/123/read"

            // Act.
            let response = try await application.sendRequest(
                to: path,
                method: .POST,
                body: DirectMessageRequestDto(recipientIds: ["123"], note: "Hello"))

            // Assert.
            #expect(response.status == .unauthorized)
        }
    }
}
