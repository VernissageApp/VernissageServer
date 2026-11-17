//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Number of conversations with unread incoming messages, including muted conversations.
struct DirectConversationsUnreadCountDto: Content {
    let count: Int
}
