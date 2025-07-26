//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Status hashtag (history).
final class StatusHashtagHistory: Model, @unchecked Sendable {
    static let schema: String = "StatusHashtagHistories"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "hashtag")
    var hashtag: String

    @Field(key: "hashtagNormalized")
    var hashtagNormalized: String
    
    @Parent(key: "statusHistoryId")
    var statusHistory: StatusHistory
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, statusHistoryId: Int64, from statusHashtag: StatusHashtag) {
        self.init()

        self.id = id
        self.$statusHistory.id = statusHistoryId
        
        self.hashtag = statusHashtag.hashtag
        self.hashtagNormalized = statusHashtag.hashtagNormalized
    }
}

/// Allows `StatusHashtagHistory` to be encoded to and decoded from HTTP messages.
extension StatusHashtagHistory: Content { }

extension NoteTagDto {
    init(from statusHashtag: StatusHashtagHistory, baseAddress: String) {
        self.init(
            type: "Hashtag",
            name: "#\(statusHashtag.hashtag)",
            href: "\(baseAddress)/tags/\(statusHashtag.hashtag)")
    }
}
