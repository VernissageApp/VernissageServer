//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit


struct CategoryHashtagDto {
    var id: String?
    var hashtag: String
    var hashtagNormalized: String
}

extension CategoryHashtagDto {
    init(from categoryHashtag: CategoryHashtag) {
        self.id = categoryHashtag.stringId()
        self.hashtag = categoryHashtag.hashtag
        self.hashtagNormalized = categoryHashtag.hashtagNormalized
    }
}

extension CategoryHashtagDto: Content { }
