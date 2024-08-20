//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake
import ActivityPubKit

/// Trending hashtag.
final class TrendingHashtag: Model, @unchecked Sendable {
    static let schema: String = "TrendingHashtags"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?
    
    @Field(key: "trendingPeriod")
    var trendingPeriod: TrendingPeriod

    @Field(key: "hashtag")
    var hashtag: String

    @Field(key: "hashtagNormalized")
    var hashtagNormalized: String
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil, trendingPeriod: TrendingPeriod, hashtag: String, hashtagNormalized: String) {
        self.init()

        self.trendingPeriod = trendingPeriod
        self.hashtag = hashtag
        self.hashtagNormalized = hashtagNormalized
    }
}

/// Allows `TrendingHashtag` to be encoded to and decoded from HTTP messages.
extension TrendingHashtag: Content { }
