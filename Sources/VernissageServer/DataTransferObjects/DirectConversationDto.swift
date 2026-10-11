//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Personalized inbox entry; participants and preview only describe messages visible to the viewer.
struct DirectConversationDto: Content {
    let id: String
    let participants: [UserDto]
    let lastStatusId: String?
    let summary: String?
    let lastActivityAt: Date
    let lastReadAt: Date?
    let hasUnreadMessages: Bool
    let isMuted: Bool

    /// Set when the latest visible message was removed; summary is empty and lastStatusId retains its original id.
    var lastMessageDeletedAt: Date? = nil
}
