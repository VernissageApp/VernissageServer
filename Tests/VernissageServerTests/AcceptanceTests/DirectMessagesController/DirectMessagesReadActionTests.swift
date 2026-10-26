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
    @Suite("DirectMessages (GET /direct-messages/123)", .serialized, .tags(.directMessages))
    struct DirectMessagesReadActionTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Details disclose only participants and preview from visible messages`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let limited = try await application.sendDirectMessage(
                author: fixture.recipient,
                recipients: [fixture.outsider],
                note: "Limited",
                conversationId: fixture.message.conversationId,
                replyToStatusId: fixture.message.id)

            // Act.
            let result = try await application.getResponse(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            let original = try await application.getResponse(
                as: .user(userName: fixture.author.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            // Assert.
            #expect(result.summary == "Limited")
            #expect(result.lastStatusId == limited.id)
            #expect(Set(result.participants.compactMap(\.id)) == Set([fixture.recipient.stringId(), fixture.outsider.stringId()].compactMap { $0 }))
            #expect(original.lastStatusId == fixture.message.id)
            #expect(original.summary == "Hello")
        }

        @Test
        func `Foreign conversation returns not found`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)",
                method: .GET)

            // Assert.
            #expect(response.status == .notFound)
        }

        @Test
        func `Anonymous request is rejected`() async throws {

            // Arrange.
            let path = "/direct-messages/123"

            // Act.
            let response = try await application.sendRequest(
                to: path,
                method: .GET)

            // Assert.
            #expect(response.status == .unauthorized)
        }
    }
}
