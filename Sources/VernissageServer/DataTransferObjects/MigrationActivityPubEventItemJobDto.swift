//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Queue payload identifying a persistent account migration delivery.
struct MigrationActivityPubEventItemJobDto: Content {
    let itemId: Int64
}
