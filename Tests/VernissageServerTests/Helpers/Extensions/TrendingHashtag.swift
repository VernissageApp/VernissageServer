//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Application {
    func createTrendingHashtag(trendingPeriod: TrendingPeriod, hashtag: String) async throws {
        let trendingHashtag = TrendingHashtag(trendingPeriod: trendingPeriod, hashtag: hashtag, hashtagNormalized: hashtag.uppercased())
        _ = try await trendingHashtag.save(on: self.db)
    }
}
