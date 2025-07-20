//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

final class StatusDto {
    let id: String?
    let isLocal: Bool
    let note: String?
    let visibility: StatusVisibilityDto
    let sensitive: Bool
    let contentWarning: String?
    let commentsDisabled: Bool
    let replyToStatusId: String?
    let user: UserDto
    let attachments: [AttachmentDto]?
    let tags: [HashtagDto]?
    let category: CategoryDto?
    let noteHtml: String?
    let repliesCount: Int
    let reblogsCount: Int
    let favouritesCount: Int
    let favourited: Bool
    let reblogged: Bool
    let bookmarked: Bool
    let featured: Bool
    let reblog: StatusDto?
    let application: String?
    let activityPubId: String
    let activityPubUrl: String
    let publishedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case isLocal
        case note
        case visibility
        case sensitive
        case contentWarning
        case commentsDisabled
        case replyToStatusId
        case user
        case attachments
        case tags
        case category
        case noteHtml
        case repliesCount
        case reblogsCount
        case favouritesCount
        case favourited
        case reblogged
        case bookmarked
        case featured
        case reblog
        case application
        case activityPubId
        case activityPubUrl
        case publishedAt
        case createdAt
        case updatedAt
    }
    
    private init(
        id: String?,
        isLocal: Bool,
        note: String?,
        noteHtml: String?,
        visibility: StatusVisibilityDto,
        sensitive: Bool,
        contentWarning: String? = nil,
        commentsDisabled: Bool,
        replyToStatusId: String? = nil,
        user: UserDto,
        activityPubId: String,
        activityPubUrl: String,
        attachments: [AttachmentDto]? = nil,
        tags: [HashtagDto]? = nil,
        reblog: StatusDto? = nil,
        category: CategoryDto?,
        application: String?,
        repliesCount: Int = 0,
        reblogsCount: Int = 0,
        favouritesCount: Int = 0,
        favourited: Bool = false,
        reblogged: Bool = false,
        bookmarked: Bool = false,
        featured: Bool = false,
        publishedAt: Date?,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.isLocal = isLocal
        self.note = note
        self.visibility = visibility
        self.sensitive = sensitive
        self.contentWarning = contentWarning
        self.commentsDisabled = commentsDisabled
        self.replyToStatusId = replyToStatusId
        self.user = user
        self.activityPubId = activityPubId
        self.activityPubUrl = activityPubUrl
        self.attachments = attachments
        self.tags = tags
        self.noteHtml = noteHtml
        self.repliesCount = repliesCount
        self.reblogsCount = reblogsCount
        self.favouritesCount = favouritesCount
        self.favourited = favourited
        self.reblogged = reblogged
        self.bookmarked = bookmarked
        self.featured = featured
        self.reblog = reblog
        self.category = category
        self.application = application
        self.publishedAt = publishedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        isLocal = try values.decodeIfPresent(Bool.self, forKey: .isLocal) ?? true
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        noteHtml = try values.decodeIfPresent(String.self, forKey: .noteHtml) ?? ""
        visibility = try values.decodeIfPresent(StatusVisibilityDto.self, forKey: .visibility) ?? .public
        sensitive = try values.decodeIfPresent(Bool.self, forKey: .sensitive) ?? false
        contentWarning = try values.decodeIfPresent(String.self, forKey: .contentWarning)
        commentsDisabled = try values.decodeIfPresent(Bool.self, forKey: .commentsDisabled) ?? false
        replyToStatusId = try values.decodeIfPresent(String.self, forKey: .replyToStatusId)
        user = try values.decode(UserDto.self, forKey: .user)
        activityPubId = try values.decode(String.self, forKey: .activityPubId)
        activityPubUrl = try values.decode(String.self, forKey: .activityPubUrl)
        attachments = try values.decodeIfPresent([AttachmentDto].self, forKey: .attachments)
        tags = try values.decodeIfPresent([HashtagDto].self, forKey: .tags)
        repliesCount = try values.decodeIfPresent(Int.self, forKey: .repliesCount) ?? 0
        reblogsCount = try values.decodeIfPresent(Int.self, forKey: .reblogsCount) ?? 0
        favouritesCount = try values.decodeIfPresent(Int.self, forKey: .favouritesCount) ?? 0
        favourited = try values.decodeIfPresent(Bool.self, forKey: .favourited) ?? false
        reblogged = try values.decodeIfPresent(Bool.self, forKey: .reblogged) ?? false
        bookmarked = try values.decodeIfPresent(Bool.self, forKey: .bookmarked) ?? false
        featured = try values.decodeIfPresent(Bool.self, forKey: .featured) ?? false
        reblog = try values.decodeIfPresent(StatusDto.self, forKey: .reblog)
        category = try values.decodeIfPresent(CategoryDto.self, forKey: .category)
        application = try values.decodeIfPresent(String.self, forKey: .application) ?? ""
        publishedAt = try values.decodeIfPresent(Date.self, forKey: .publishedAt)
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(isLocal, forKey: .isLocal)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(visibility, forKey: .visibility)
        try container.encodeIfPresent(sensitive, forKey: .sensitive)
        try container.encodeIfPresent(contentWarning, forKey: .contentWarning)
        try container.encodeIfPresent(commentsDisabled, forKey: .commentsDisabled)
        try container.encodeIfPresent(replyToStatusId, forKey: .replyToStatusId)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(activityPubId, forKey: .activityPubId)
        try container.encodeIfPresent(activityPubUrl, forKey: .activityPubUrl)
        try container.encodeIfPresent(attachments, forKey: .attachments)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(noteHtml, forKey: .noteHtml)
        try container.encodeIfPresent(repliesCount, forKey: .repliesCount)
        try container.encodeIfPresent(reblogsCount, forKey: .reblogsCount)
        try container.encodeIfPresent(favouritesCount, forKey: .favouritesCount)
        try container.encodeIfPresent(favourited, forKey: .favourited)
        try container.encodeIfPresent(reblogged, forKey: .reblogged)
        try container.encodeIfPresent(bookmarked, forKey: .bookmarked)
        try container.encodeIfPresent(featured, forKey: .featured)
        try container.encodeIfPresent(reblog, forKey: .reblog)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(application, forKey: .application)
        try container.encodeIfPresent(publishedAt, forKey: .publishedAt)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

extension StatusDto {
    convenience init(
        from status: Status,
        userNameMaps: [String: String]?,
        baseAddress: String,
        baseImagesPath: String,
        attachments: [AttachmentDto]?,
        reblog: StatusDto?,
        isFavourited: Bool,
        isReblogged: Bool,
        isBookmarked: Bool,
        isFeatured: Bool
    ) {
        let replyToStatusId: String? = if let replyToStatusId = status.$replyToStatus.id { "\(replyToStatusId)" } else { nil }
        let noteHtml = status.isLocal ? status.note?.html(baseAddress: baseAddress, wrapInParagraph: true, userNameMaps: userNameMaps) : status.note
        
        self.init(
            id: status.stringId(),
            isLocal: status.isLocal,
            note: status.note,
            noteHtml: noteHtml,
            visibility: StatusVisibilityDto.from(status.visibility),
            sensitive: status.sensitive,
            contentWarning: status.contentWarning,
            commentsDisabled: status.commentsDisabled,
            replyToStatusId: replyToStatusId,
            user: UserDto(from: status.user, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
            activityPubId: status.activityPubId,
            activityPubUrl: status.activityPubUrl,
            attachments: attachments,
            tags: status.hashtags.map({ HashtagDto(url: "\(baseAddress)/tags/\($0.hashtag)", name: $0.hashtag) }),
            reblog: reblog,
            category: CategoryDto(from: status.category),
            application: status.application,
            repliesCount: status.repliesCount,
            reblogsCount: status.reblogsCount,
            favouritesCount: status.favouritesCount,
            favourited: isFavourited,
            reblogged: isReblogged,
            bookmarked: isBookmarked,
            featured: isFeatured,
            publishedAt: status.publishedAt,
            createdAt: status.createdAt,
            updatedAt: status.updatedAt
        )
    }
    
    convenience init(
        from status: StatusHistory,
        userNameMaps: [String: String]?,
        baseAddress: String,
        baseImagesPath: String,
        attachments: [AttachmentDto]?,
        reblog: StatusDto?,
        isFavourited: Bool,
        isReblogged: Bool,
        isBookmarked: Bool,
        isFeatured: Bool
    ) {
        let replyToStatusId: String? = if let replyToStatusId = status.$replyToStatus.id { "\(replyToStatusId)" } else { nil }
        let noteHtml = status.isLocal ? status.note?.html(baseAddress: baseAddress, wrapInParagraph: true, userNameMaps: userNameMaps) : status.note
        
        self.init(
            id: status.stringId(),
            isLocal: status.isLocal,
            note: status.note,
            noteHtml: noteHtml,
            visibility: StatusVisibilityDto.from(status.visibility),
            sensitive: status.sensitive,
            contentWarning: status.contentWarning,
            commentsDisabled: status.commentsDisabled,
            replyToStatusId: replyToStatusId,
            user: UserDto(from: status.user, baseImagesPath: baseImagesPath, baseAddress: baseAddress),
            activityPubId: status.activityPubId,
            activityPubUrl: status.activityPubUrl,
            attachments: attachments,
            tags: status.hashtags.map({ HashtagDto(url: "\(baseAddress)/tags/\($0.hashtag)", name: $0.hashtag) }),
            reblog: reblog,
            category: CategoryDto(from: status.category),
            application: status.application,
            repliesCount: status.repliesCount,
            reblogsCount: status.reblogsCount,
            favouritesCount: status.favouritesCount,
            favourited: isFavourited,
            reblogged: isReblogged,
            bookmarked: isBookmarked,
            featured: isFeatured,
            publishedAt: status.publishedAt,
            createdAt: status.createdAt,
            updatedAt: status.updatedAt
        )
    }
}

extension StatusDto: Content { }
