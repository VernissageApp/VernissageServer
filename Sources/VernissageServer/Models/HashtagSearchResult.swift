//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Aggregated hashtag search result.
struct HashtagSearchResult: Content {
    let hashtag: String
    let amount: Int
}
