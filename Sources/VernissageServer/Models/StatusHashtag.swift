//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake
import ActivityPubKit

/// Status hashtag.
final class StatusHashtag: Model, @unchecked Sendable {
    static let schema: String = "StatusHashtags"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "hashtag")
    var hashtag: String

    @Field(key: "hashtagNormalized")
    var hashtagNormalized: String
    
    @Parent(key: "statusId")
    var status: Status
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil, statusId: Int64, hashtag: String) {
        self.init()

        self.$status.id = statusId
        self.hashtag = hashtag
        self.hashtagNormalized = hashtag.uppercased().trimmingCharacters(in: [" "])
    }
}

/// Allows `StatusHashtag` to be encoded to and decoded from HTTP messages.
extension StatusHashtag: Content { }

extension NoteHashtagDto {
    init(from statusHashtag: StatusHashtag, baseAddress: String) {
        self.init(type: "Hashtag", name: "#\(statusHashtag.hashtag)", href: "\(baseAddress)/hashtag/\(statusHashtag.hashtag)")
    }
}
