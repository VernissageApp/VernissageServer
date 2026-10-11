//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

/// Notifications are saved with the message and dispatched only after its transaction commits.
struct DirectMessageStoreResult {
    let status: Status
    let notifications: [Notification]
}
