//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import Frostflake

final class Status: Model {
    static let schema: String = "Statuses"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "isLocal")
    var isLocal: Bool
    
    @Field(key: "note")
    var note: String
    
    @Field(key: "visibility")
    var visibility: StatusVisibility
    
    @Field(key: "sensitive")
    var sensitive: Bool

    @Field(key: "contentWarning")
    var contentWarning: String?

    @Field(key: "commentsDisabled")
    var commentsDisabled: Bool

    @Parent(key: "userId")
    var user: User
    
    @OptionalParent(key: "replyToStatusId")
    var replyToStatus: Status?
    
    @Children(for: \.$status)
    var attachments: [Attachment]

    @Children(for: \.$replyToStatus)
    var comments: [Status]
    
    @Children(for: \.$status)
    var hashtags: [StatusHashtag]
    
    /// Id of the status shared via ActivityPub protocol,
    /// e.g. `https://mastodon.social/users/mczachurski/statuses/111000972200397678`.
    @Field(key: "activityPubId")
    var activityPubId: String?

    /// Url of the status shared via ActivityPub protocol,
    /// e.g. `https://mastodon.social/@mczachurski/111000972200397678`.
    @Field(key: "activityPubUrl")
    var activityPubUrl: String?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() {
        self.id = .init(bitPattern: Frostflake.generate())
    }

    convenience init(id: Int64? = nil,
                     isLocal: Bool = true,
                     userId: Int64,
                     note: String,
                     activityPubId: String? = nil,
                     activityPubUrl: String? = nil,
                     visibility: StatusVisibility = .public,
                     sensitive: Bool = false,
                     contentWarning: String? = nil,
                     commentsDisabled: Bool = false,
                     replyToStatusId: Int64? = nil
    ) {
        self.init()

        self.isLocal = isLocal
        self.$user.id = userId
        self.$replyToStatus.id = replyToStatusId
        
        self.note = note
        self.activityPubId = activityPubId
        self.activityPubUrl = activityPubUrl
        self.visibility = visibility
        self.sensitive = sensitive
        self.contentWarning = contentWarning
        self.commentsDisabled = commentsDisabled
    }
}

/// Allows `Status` to be encoded to and decoded from HTTP messages.
extension Status: Content { }
