//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Only messages actually displayed by the client should be marked as read.
struct DirectConversationReadRequestDto: Content {
    var statusIds: [String]
}
