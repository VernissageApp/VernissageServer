//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Payload used to start processing a persistent email delivery.
struct EmailSenderJobDto: Content {
    let emailDeliveryId: Int64
}
