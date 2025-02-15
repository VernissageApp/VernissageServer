//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Status emoji.
final class StatusEmoji: Model, @unchecked Sendable {
    static let schema: String = "StatusEmojis"

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
    
    @Parent(key: "statusId")
    var status: Status
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, statusId: Int64, activityPubId: String, name: String, mediaType: String, fileName: String) {
        self.init()

        self.id = id
        self.$status.id = statusId
        
        self.activityPubId = activityPubId
        self.name = name
        self.mediaType = mediaType
        self.fileName = fileName
    }
}

/// Allows `StatusEmoji` to be encoded to and decoded from HTTP messages.
extension StatusEmoji: Content { }

extension NoteTagDto {
    init(from statusEmoji: StatusEmoji, baseAddress: String, baseStoragePath: String) {
        self.init(type: "Emoji",
                  name:statusEmoji.name,
                  id: "\(baseAddress)/emojis/\(statusEmoji.stringId() ?? "")",
                  updated: statusEmoji.updatedAt ?? statusEmoji.createdAt ?? Date(),
                  icon: NoteTagIconDto(type: "Image",
                                       mediaType: statusEmoji.mediaType,
                                       url: baseStoragePath.finished(with: "/") + statusEmoji.fileName))
    }
}
