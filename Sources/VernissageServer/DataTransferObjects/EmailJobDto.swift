//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Payload handed from `EmailSenderJob` to the SMTP-specific `EmailJob`.
struct EmailJobDto: Content {
    let emailDeliveryId: Int64
    let processingToken: String
    let email: EmailDto
}
