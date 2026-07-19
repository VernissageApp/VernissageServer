//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Kind of timeline for which a marker is stored.
enum TimelineKind: Int, Codable {
    case `private` = 1
    case local = 2
    case federated = 3
    case featured = 4
}
