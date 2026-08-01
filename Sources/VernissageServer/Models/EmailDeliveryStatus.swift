//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Processing status of an email delivery.
enum EmailDeliveryStatus: Int, Codable, Sendable {
    /// Email is waiting to be enqueued for sending.
    case waiting = 1

    /// Email has been claimed by a worker and is being processed.
    case processing = 2

    /// Email failed temporarily and is waiting for another attempt.
    case retryWaiting = 3

    /// Email has been delivered successfully.
    case succeeded = 4

    /// Email exhausted the allowed number of attempts.
    case permanentFailure = 5
}
