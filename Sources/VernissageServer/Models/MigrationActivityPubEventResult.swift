//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Result of an ActivityPub account migration event.
enum MigrationActivityPubEventResult: Int, Codable {
    /// Event is waiting for processing.
    case waiting = 1

    /// At least one event item is being processed.
    case processing = 2

    /// All event items have been processed successfully.
    case finished = 3

    /// Event processing finished, but at least one item failed permanently.
    case finishedWithErrors = 4

    /// Event could not be processed because of a critical error.
    case failed = 5

    /// Event was cancelled before all of its items were delivered.
    case cancelled = 6
}
