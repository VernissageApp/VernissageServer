//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// The current user's notification preference for a direct conversation.
struct DirectConversationMuteRequestDto: Content {
    var isMuted: Bool
}
