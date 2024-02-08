//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import XCTVapor
import Fluent

extension TrendingHashtag {
    static func create(trendingPeriod: TrendingPeriod, hashtag: String) async throws {
        let trendingHashtag = TrendingHashtag(trendingPeriod: trendingPeriod, hashtag: hashtag, hashtagNormalized: hashtag.uppercased())
        _ = try await trendingHashtag.save(on: SharedApplication.application().db)
    }
}
