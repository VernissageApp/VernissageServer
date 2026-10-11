//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Fluent
import Testing
import Vapor

/// Endpoint-created fixture: no direct database insert bypasses message creation behavior.
struct DirectMessageFixture {
    let author: User
    let recipient: User
    let outsider: User
    let message: DirectMessageDto
}

extension Application {
    func createDirectMessageUser(isLocal: Bool = true) async throws -> User {
        let user = try await createUser(userName: "dm" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(), isLocal: isLocal)

        if isLocal == false {
            user.userInbox = "https://remote.example/actors/\(user.userName)/inbox"
            user.sharedInbox = "https://remote.example/shared/inbox"
            try await user.save(on: db)
        }

        return user
    }

    func sendDirectMessage(author: User, recipients: [User], note: String = "Hello", conversationId: String? = nil,
                           replyToStatusId: String? = nil, attachmentIds: [String] = []) async throws -> DirectMessageDto {
        let path = conversationId.map { "/direct-messages/\($0)/statuses" } ?? "/direct-messages"
        let response = try await sendRequest(as: .user(userName: author.userName, password: "p@ssword"), to: path, method: .POST,
            body: DirectMessageRequestDto(recipientIds: try recipients.map { String(try $0.requireID()) }, note: note,
                                          attachmentIds: attachmentIds, replyToStatusId: replyToStatusId))
        #expect(response.status == .created)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601

        return try response.content.decode(DirectMessageDto.self, using: decoder)
    }

    func createDirectMessageFixture() async throws -> DirectMessageFixture {
        let author = try await createDirectMessageUser()
        let recipient = try await createDirectMessageUser()
        let outsider = try await createDirectMessageUser()
        let message = try await sendDirectMessage(author: author, recipients: [recipient])

        return DirectMessageFixture(author: author, recipient: recipient, outsider: outsider, message: message)
    }
}

/// Unwraps identifiers outside assertion macros to avoid nested Swift Testing macro expansion.
func requireDirectMessageId(_ value: String) throws -> Int64 {
    try #require(value.toId())
}
