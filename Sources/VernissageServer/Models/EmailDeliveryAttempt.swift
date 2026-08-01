//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Information about a started email delivery attempt.
struct EmailDeliveryAttempt: Sendable {
    /// Token proving ownership of the active SMTP attempt.
    let processingToken: String

    /// Number of SMTP attempts made for the email delivery, including the active attempt.
    let attempts: Int
}
