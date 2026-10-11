//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// A live message or content-free deletion marker, visible only to its author and original explicit audience.
/// `deletedAt` identifies a marker; `status` is absent for deleted messages. Metadata preserves its position in the UI.
struct DirectMessageDto: Content {
    let id: String
    let conversationId: String
    let status: StatusDto?
    let recipients: [UserDto]
    let readAt: Date?
    var deletedAt: Date? = nil
    var author: UserDto? = nil
    var publishedAt: Date? = nil
    var replyToStatusId: String? = nil
}
