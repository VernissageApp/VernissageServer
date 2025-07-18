//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Status history.
final class StatusHistory: Model, @unchecked Sendable {
    static let schema: String = "StatusHistories"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "orginalStatusId")
    var orginalStatus: Status
    
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
    
    @Children(for: \.$statusHistory)
    var attachments: [AttachmentHistory]
    
    @Children(for: \.$statusHistory)
    var hashtags: [StatusHashtagHistory]

    @Children(for: \.$statusHistory)
    var mentions: [StatusMentionHistory]

    @Children(for: \.$statusHistory)
    var emojis: [StatusEmojiHistory]
    
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
    
    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, from status: Status) throws {
        self.init()

        self.id = id
        self.$orginalStatus.id = try status.requireID()

        self.$user.id = status.$user.id
        self.$replyToStatus.id = status.$replyToStatus.id
        self.$mainReplyToStatus.id = status.$mainReplyToStatus.id
        self.$reblog.id = status.$reblog.id
        self.$category.id = status.$category.id
        
        self.isLocal = status.isLocal
        self.note = status.note
        self.visibility = status.visibility
        self.activityPubId = status.activityPubId
        self.activityPubUrl = status.activityPubUrl
        
        self.sensitive = status.sensitive
        self.contentWarning = status.contentWarning
        self.commentsDisabled = status.commentsDisabled
        self.application = status.application
        self.publishedAt = status.publishedAt
        
        self.repliesCount = 0
        self.reblogsCount = 0
        self.favouritesCount = 0
    }
}

/// Allows `StatusHistory` to be encoded to and decoded from HTTP messages.
extension StatusHistory: Content { }

extension [StatusHistory] {
    func sorted() -> [StatusHistory] {
        self.sorted { left, right in
            (left.id ?? 0) < (right.id ?? 0)
        }
    }
}
