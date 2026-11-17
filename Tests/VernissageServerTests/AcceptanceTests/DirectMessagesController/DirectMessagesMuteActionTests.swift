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
    @Suite("DirectMessages (PUT /direct-messages/123/mute)", .serialized, .tags(.directMessages))
    struct DirectMessagesMuteActionTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Mute is personal and does not change read state or activity`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let before = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            var results: [(isMuted: Bool, status: HTTPResponseStatus, conversation: DirectConversationDto)] = []

            // Act.
            for muted in [true, false] {
                let response = try await application.sendRequest(
                    as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                    to: "/direct-messages/\(fixture.message.conversationId)/mute",
                    method: .PUT,
                    body: DirectConversationMuteRequestDto(isMuted: muted))

                let after = try await application.getResponse(
                    as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                    to: "/direct-messages/\(fixture.message.conversationId)",
                    method: .GET,
                    decodeTo: DirectConversationDto.self)

                results.append((isMuted: muted, status: response.status, conversation: after))
            }

            let foreign = try await application.sendRequest(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/mute",
                method: .PUT,
                body: DirectConversationMuteRequestDto(isMuted: true))

            // Assert.
            for result in results {
                #expect(result.status == .noContent)
                #expect(result.conversation.isMuted == result.isMuted)
                #expect(result.conversation.hasUnreadMessages)
                #expect(result.conversation.lastActivityAt == before.lastActivityAt)
            }

            #expect(foreign.status == .notFound)
        }

        @Test
        func `Anonymous request is rejected`() async throws {

            // Arrange.
            let path = "/direct-messages/123/mute"

            // Act.
            let response = try await application.sendRequest(
                to: path,
                method: .PUT)

            // Assert.
            #expect(response.status == .unauthorized)
        }

        @Test
        func `Muted conversations suppress notifications while messages remain unread`() async throws {
            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            _ = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/mute",
                method: .PUT,
                body: DirectConversationMuteRequestDto(isMuted: true))

            // Act.
            let muted = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient, fixture.outsider],
                conversationId: fixture.message.conversationId)

            let details = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)",
                method: .GET,
                decodeTo: DirectConversationDto.self)

            _ = try await application.sendRequest(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages/\(fixture.message.conversationId)/mute",
                method: .PUT,
                body: DirectConversationMuteRequestDto(isMuted: false))

            let unmuted = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                conversationId: fixture.message.conversationId)

            let notifications = try await Notification.query(on: application.db)
                .filter(\.$status.$id ~~ [requireDirectMessageId(muted.id), requireDirectMessageId(unmuted.id)])
                .all()

            // Assert.
            #expect(details.isMuted)
            #expect(details.hasUnreadMessages)
            #expect(details.lastStatusId == muted.id)
            #expect(notifications.count == 2)
            #expect(notifications.contains { $0.$status.id == muted.id.toId() && $0.$user.id == fixture.outsider.id })
            #expect(notifications.contains { $0.$status.id == unmuted.id.toId() && $0.$user.id == fixture.recipient.id })
        }
    }
}
