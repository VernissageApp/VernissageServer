//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Status.
final class Status: Model, @unchecked Sendable {
    static let schema: String = "Statuses"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Field(key: "isLocal")
    var isLocal: Bool
    
    @Field(key: "note")
    var note: String?
    
    @Field(key: "visibility")
    var visibility: StatusVisibility
    
    @Field(key: "sensitive")
    var sensitive: Bool

    @Field(key: "contentWarning")
    var contentWarning: String?

    @Field(key: "commentsDisabled")
    var commentsDisabled: Bool

    @Field(key: "repliesCount")
    var repliesCount: Int
    
    @Field(key: "reblogsCount")
    var reblogsCount: Int
    
    @Field(key: "favouritesCount")
    var favouritesCount: Int
    
    @Field(key: "application")
    var application: String?
    
    @Parent(key: "userId")
    var user: User
    
    /// Status is reply for this status.
    @OptionalParent(key: "replyToStatusId")
    var replyToStatus: Status?

    /// Main status commented in the chain of the comments.
    @OptionalParent(key: "mainReplyToStatusId")
    var mainReplyToStatus: Status?
    
    /// Status reblogged this status.
    @OptionalParent(key: "reblogId")
    var reblog: Status?
    
    @OptionalParent(key: "categoryId")
    var category: Category?
    
    @Children(for: \.$status)
    var attachments: [Attachment]

    @Children(for: \.$replyToStatus)
    var comments: [Status]
    
    @Children(for: \.$status)
    var hashtags: [StatusHashtag]

    @Children(for: \.$status)
    var mentions: [StatusMention]

    @Children(for: \.$status)
    var emojis: [StatusEmoji]
    
    /// Id of the status shared via ActivityPub protocol,
    /// e.g. `https://mastodon.social/users/mczachurski/statuses/111000972200397678`.
    @Field(key: "activityPubId")
    var activityPubId: String

    /// Url of the status shared via ActivityPub protocol,
    /// e.g. `https://mastodon.social/@mczachurski/111000972200397678`.
    @Field(key: "activityPubUrl")
    var activityPubUrl: String
    
    @Timestamp(key: "publishedAt", on: .none)
    var publishedAt: Date?
    
    @Timestamp(key: "updatedByUserAt", on: .none)
    var updatedByUserAt: Date?
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64,
                     isLocal: Bool = true,
                     userId: Int64,
                     note: String?,
                     baseAddress: String,
                     userName: String,
                     application: String?,
                     categoryId: Int64?,
                     visibility: StatusVisibility = .public,
                     sensitive: Bool = false,
                     contentWarning: String? = nil,
                     commentsDisabled: Bool = false,
                     replyToStatusId: Int64? = nil,
                     mainReplyToStatusId: Int64? = nil,
                     reblogId: Int64? = nil,
                     publishedAt: Date? = nil
    ) {
        self.init()

        self.id = id
        self.isLocal = isLocal
        self.$user.id = userId
        self.$replyToStatus.id = replyToStatusId
        self.$mainReplyToStatus.id = mainReplyToStatusId
        self.$reblog.id = reblogId
        self.$category.id = categoryId
        
        self.note = note
        self.activityPubId = "\(baseAddress)/actors/\(userName)/statuses/\(self.stringId() ?? "")"
        self.activityPubUrl = "\(baseAddress)/@\(userName)/\(self.stringId() ?? "")"
        self.visibility = visibility
        self.sensitive = sensitive
        self.contentWarning = contentWarning
        self.commentsDisabled = commentsDisabled
        self.application = application
        self.publishedAt = publishedAt

        self.repliesCount = 0
        self.reblogsCount = 0
        self.favouritesCount = 0
    }
    
    convenience init(id: Int64,
                     isLocal: Bool = true,
                     userId: Int64,
                     note: String?,
                     activityPubId: String,
                     activityPubUrl: String,
                     application: String?,
                     categoryId: Int64?,
                     visibility: StatusVisibility = .public,
                     sensitive: Bool = false,
                     contentWarning: String? = nil,
                     commentsDisabled: Bool = false,
                     replyToStatusId: Int64? = nil,
                     mainReplyToStatusId: Int64? = nil,
                     reblogId: Int64? = nil,
                     publishedAt: Date? = nil
    ) {
        self.init()

        self.id = id
        self.isLocal = isLocal
        self.$user.id = userId
        self.$replyToStatus.id = replyToStatusId
        self.$mainReplyToStatus.id = mainReplyToStatusId
        self.$reblog.id = reblogId
        self.$category.id = categoryId
        
        self.note = note
        self.activityPubId = activityPubId
        self.activityPubUrl = activityPubUrl
        self.visibility = visibility
        self.sensitive = sensitive
        self.contentWarning = contentWarning
        self.commentsDisabled = commentsDisabled
        self.application = application
        self.publishedAt = publishedAt
        
        self.repliesCount = 0
        self.reblogsCount = 0
        self.favouritesCount = 0
    }
}

/// Allows `Status` to be encoded to and decoded from HTTP messages.
extension Status: Content { }

extension [Status] {
    func sorted() -> [Status] {
        self.sorted { left, right in
            (left.id ?? 0) < (right.id ?? 0)
        }
    }
}
