//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import VaporTesting
import Fluent

extension Application {
    func createTrendingHashtag(trendingPeriod: TrendingPeriod, hashtag: String) async throws {
        let id = await ApplicationManager.shared.generateId()
        let trendingHashtag = TrendingHashtag(id: id, trendingPeriod: trendingPeriod, hashtag: hashtag, hashtagNormalized: hashtag.uppercased(), amount: 1)
        _ = try await trendingHashtag.save(on: self.db)
    }
    
    func getAllTrendingHashtags() async throws -> [TrendingHashtag] {
        try await TrendingHashtag.query(on: self.db)
            .all()
    }
}
