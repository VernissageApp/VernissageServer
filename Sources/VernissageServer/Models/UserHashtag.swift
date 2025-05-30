//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's hashtag.
final class UserHashtag: Model, @unchecked Sendable {
    static let schema: String = "UserHashtags"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "hashtag")
    var hashtag: String

    @Field(key: "hashtagNormalized")
    var hashtagNormalized: String
    
    @Parent(key: "userId")
    var user: User
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, userId: Int64, hashtag: String) {
        self.init()

        self.id = id
        self.$user.id = userId
        self.hashtag = hashtag
        self.hashtagNormalized = hashtag.uppercased()
    }
}

/// Allows `UserHashtag` to be encoded to and decoded from HTTP messages.
extension UserHashtag: Content { }
