//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Type of Activity Pub status event.
enum StatusActivityPubEventType: Int, Codable {
    case create = 1
    case update = 2
    case like = 3
    case unlike = 4
    case announce = 5
    case unannounce = 6
    case pin = 7
    case unpin = 8
}
