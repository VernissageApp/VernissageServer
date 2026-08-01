//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Processing status of a single ActivityPub account migration delivery.
enum MigrationActivityPubEventItemStatus: Int, Codable {
    /// Item is waiting for its first processing attempt.
    case waiting = 1

    /// Item has been claimed by a worker and is being processed.
    case processing = 2

    /// Item failed temporarily and is waiting for another attempt.
    case retryWaiting = 3

    /// Item has been delivered successfully.
    case succeeded = 4

    /// Item failed permanently or exhausted the allowed number of attempts.
    case permanentFailure = 5

    /// Item was cancelled before it was delivered.
    case cancelled = 6
}
