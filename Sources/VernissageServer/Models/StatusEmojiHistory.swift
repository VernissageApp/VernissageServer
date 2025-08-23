//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Status emoji (history).
final class StatusEmojiHistory: Model, @unchecked Sendable {
    static let schema: String = "StatusEmojisHistories"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "activityPubId")
    var activityPubId: String
    
    @Field(key: "name")
    var name: String

    @Field(key: "mediaType")
    var mediaType: String
    
    @Field(key: "fileName")
    var fileName: String
    
    @Parent(key: "statusHistoryId")
    var statusHistory: StatusHistory
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, statusHistoryId: Int64, from statusEmoji: StatusEmoji) {
        self.init()

        self.id = id
        self.$statusHistory.id = statusHistoryId
        
        self.activityPubId = statusEmoji.activityPubId
        self.name = statusEmoji.name
        self.mediaType = statusEmoji.mediaType
        self.fileName = statusEmoji.fileName
    }
}

/// Allows `StatusEmojiHistory` to be encoded to and decoded from HTTP messages.
extension StatusEmojiHistory: Content { }

extension NoteTagDto {
    init(from statusEmoji: StatusEmojiHistory, baseAddress: String, baseStoragePath: String) {
        self.init(type: "Emoji",
                  name:statusEmoji.name,
                  id: "\(baseAddress)/emojis/\(statusEmoji.stringId() ?? "")",
                  updated: statusEmoji.updatedAt ?? statusEmoji.createdAt ?? Date(),
                  icon: NoteTagIconDto(type: "Image",
                                       mediaType: statusEmoji.mediaType,
                                       url: baseStoragePath.finished(with: "/") + statusEmoji.fileName))
    }
}
