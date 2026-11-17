//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// ActivityPub addressing of a status recipient.
enum StatusRecipientType: Int, Codable {
    case to = 1
    case cc = 2
}
