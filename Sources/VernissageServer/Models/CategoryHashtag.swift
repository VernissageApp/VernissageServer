//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Hashtag that can be mapped to the category.
final class CategoryHashtag: Model, @unchecked Sendable {
    static let schema: String = "CategoryHashtags"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "hashtag")
    var hashtag: String

    @Field(key: "hashtagNormalized")
    var hashtagNormalized: String
    
    @Parent(key: "categoryId")
    var category: Category
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, categoryId: Int64, hashtag: String) {
        self.init()

        self.id = id
        self.$category.id = categoryId
        self.hashtag = hashtag
        self.hashtagNormalized = hashtag.uppercased()
    }
}

/// Allows `CategoryHashtag` to be encoded to and decoded from HTTP messages.
extension CategoryHashtag: Content { }
