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
    @Suite("DirectMessages (GET /direct-messages/123/statuses)", .serialized, .tags(.directMessages))
    struct DirectMessagesStatusesActionTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Deleted markers take their original position in paginated history`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let second = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                note: "Second",
                conversationId: fixture.message.conversationId)

            let third = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                note: "Third",
                conversationId: fixture.message.conversationId)

            _ = try await application.sendRequest(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/statuses/\(second.id)",
                method: .DELETE)

            // Act.
            let page = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses?size=1&page=2",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            let conversation = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            // Assert.
            #expect(page.total == 3)
            #expect(page.data.map(\.id) == [second.id])
            #expect(page.data.first?.deletedAt != nil)
            #expect(conversation.lastStatusId == third.id)
            #expect(conversation.summary == "Third")
            #expect(conversation.lastMessageDeletedAt == nil)
            #expect(conversation.hasUnreadMessages)
        }

        @Test
        func `Messages are paginated and viewing does not mark them read`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let reply = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                note: "Second",
                conversationId: fixture.message.conversationId)

            // Act.
            let result = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses?size=1",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            // Assert.
            #expect(result.total == 2)
            #expect(result.data.first?.id == reply.id)
            #expect(result.data.first?.readAt == nil)
            #expect(result.data.first?.status?.note == "Second")
            #expect(result.data.first?.recipients.first?.id == fixture.recipient.stringId())
        }

        @Test
        func `New recipient cannot read older messages or hidden ancestors`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let reply = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.outsider],
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            // Act.
            let result = try await application.getResponse(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .GET,
                decodeTo: PaginableResultDto<DirectMessageDto>.self)

            let hidden = try await application.sendRequest(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/statuses/\(fixture.message.id)",
                method: .GET)

            let context = try await application.getResponse(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/statuses/\(reply.id)/context",
                method: .GET,
                decodeTo: StatusContextDto.self)

            // Assert.
            #expect(result.data.map(\.id) == [reply.id])
            #expect(hidden.status == .forbidden)
            #expect(context.ancestors.isEmpty)
        }

        @Test
        func `Foreign conversation history returns not found`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/statuses",
                method: .GET)

            // Assert.
            #expect(response.status == .notFound)
        }

        @Test
        func `Anonymous request is rejected`() async throws {

            // Arrange.
            let path = "/direct-messages/123/statuses"

            // Act.
            let response = try await application.sendRequest(
                to: path,
                method: .GET)

            // Assert.
            #expect(response.status == .unauthorized)
        }
    }
}
