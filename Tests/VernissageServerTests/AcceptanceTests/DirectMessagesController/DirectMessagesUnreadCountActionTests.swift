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
    @Suite("DirectMessages (GET /direct-messages/unread-count)", .serialized, .tags(.directMessages))
    struct DirectMessagesUnreadCountActionTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Count represents conversations not messages and ignores sent messages`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            _ = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                conversationId: fixture.message.conversationId)

            _ = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient])

            // Act.
            let count = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/unread-count",
                method: .GET,
                decodeTo: DirectConversationsUnreadCountDto.self)

            let senderCount = try await application.getResponse(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/direct-messages/unread-count",
                method: .GET,
                decodeTo: DirectConversationsUnreadCountDto.self)

            // Assert.
            #expect(count.count == 2)
            #expect(senderCount.count == 0)
        }

        @Test
        func `Anonymous request is rejected`() async throws {

            // Arrange.
            let path = "/direct-messages/unread-count"

            // Act.
            let response = try await application.sendRequest(
                to: path,
                method: .GET)

            // Assert.
            #expect(response.status == .unauthorized)
        }
    }
}
