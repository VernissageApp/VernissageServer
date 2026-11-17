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
    @Suite("DirectMessages (GET /direct-messages)", .serialized, .tags(.directMessages))
    struct DirectMessagesListActionTests {
        let application: Application

        init() async throws {
            application = try await ApplicationManager.shared.application()
        }

        @Test
        func `Inbox is private paginated and sorted by latest available message`() async throws {

            // Arrange.
            let fixture = try await application.createDirectMessageFixture()
            let other = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                note: "Other")

            let reply = try await application.sendDirectMessage(
                author: fixture.author,
                recipients: [fixture.recipient],
                note: "Newest",
                conversationId: fixture.message.conversationId)

            // Act.
            let result = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages?page=1&size=1",
                method: .GET,
                decodeTo: PaginableResultDto<DirectConversationDto>.self)

            let page2 = try await application.getResponse(
                as: .user(userName: fixture.recipient.userName, password: "p@ssword"),
                to: "/direct-messages?page=2&size=1",
                method: .GET,
                decodeTo: PaginableResultDto<DirectConversationDto>.self)

            let outsider = try await application.getResponse(
                as: .user(userName: fixture.outsider.userName, password: "p@ssword"),
                to: "/direct-messages",
                method: .GET,
                decodeTo: PaginableResultDto<DirectConversationDto>.self)

            // Assert.
            #expect(result.total == 2)
            #expect(result.data.count == 1)
            #expect(result.data.first?.id == fixture.message.conversationId)
            #expect(result.data.first?.lastStatusId == reply.id)
            #expect(result.data.first?.summary == "Newest")
            #expect(result.data.first?.hasUnreadMessages == true)
            #expect(page2.data.first?.id == other.conversationId)
            #expect(outsider.total == 0)
        }

        @Test(arguments: ["page=0", "size=101", "page=invalid", "size=0"])
        func `Invalid pagination is rejected`(query: String) async throws {

            // Arrange.
            let user = try await application.createDirectMessageUser()

            // Act.
            let response = try await application.sendRequest(
                as: .user(userName: user.userName, password: "p@ssword"),
                to: "/direct-messages?\(query)",
                method: .GET)

            // Assert.
            #expect(response.status == .badRequest)
        }

        @Test
        func `Anonymous request is rejected`() async throws {

            // Arrange.
            let path = "/direct-messages"

            // Act.
            let response = try await application.sendRequest(
                to: path,
                method: .GET)

            // Assert.
            #expect(response.status == .unauthorized)
        }
    }
}
