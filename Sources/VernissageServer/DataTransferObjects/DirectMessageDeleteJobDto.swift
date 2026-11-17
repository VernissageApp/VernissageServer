//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Immutable delivery data captured before deleting a private status or its audience.
/// The signing key remains in the queue payload so account cleanup cannot prevent delivery.
struct DirectMessageDeleteJobDto: Content {
    let actorId: String
    let privateKey: String?
    let recipientActorIds: [String]
    let recipientInboxes: [String?]
}
