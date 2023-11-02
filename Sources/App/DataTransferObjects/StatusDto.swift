//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct StatusDto {
    var id: String?
    var isLocal: Bool
    var note: String
    var visibility: StatusVisibilityDto
    var sensitive: Bool
    var contentWarning: String?
    var commentsDisabled: Bool
    var replyToStatusId: String?
    var user: UserDto
    var attachments: [AttachmentDto]?
    var tags: [HashtagDto]?
    var noteHtml: String?
    
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
        case noteHtml
    }
    
    init(id: String?,
         isLocal: Bool,
         note: String,
         visibility: StatusVisibilityDto,
         sensitive: Bool,
         contentWarning: String? = nil,
         commentsDisabled: Bool,
         replyToStatusId: String? = nil,
         user: UserDto,
         attachments: [AttachmentDto]? = nil,
         tags: [HashtagDto]? = nil,
         baseAddress: String) {
        self.id = id
        self.isLocal = isLocal
        self.note = note
        self.visibility = visibility
        self.sensitive = sensitive
        self.contentWarning = contentWarning
        self.commentsDisabled = commentsDisabled
        self.replyToStatusId = replyToStatusId
        self.user = user
        self.attachments = attachments
        self.tags = tags
        self.noteHtml = self.isLocal ? self.note.html(baseAddress: baseAddress) : self.note
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        isLocal = try values.decodeIfPresent(Bool.self, forKey: .isLocal) ?? true
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        visibility = try values.decodeIfPresent(StatusVisibilityDto.self, forKey: .visibility) ?? .public
        sensitive = try values.decodeIfPresent(Bool.self, forKey: .sensitive) ?? false
        contentWarning = try values.decodeIfPresent(String.self, forKey: .contentWarning)
        commentsDisabled = try values.decodeIfPresent(Bool.self, forKey: .commentsDisabled) ?? false
        replyToStatusId = try values.decodeIfPresent(String.self, forKey: .replyToStatusId)
        user = try values.decode(UserDto.self, forKey: .user)
        attachments = try values.decodeIfPresent([AttachmentDto].self, forKey: .attachments)
        tags = try values.decodeIfPresent([HashtagDto].self, forKey: .tags)
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
        try container.encodeIfPresent(attachments, forKey: .attachments)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(noteHtml, forKey: .noteHtml)
    }
}

extension StatusDto {
    init(from status: Status, baseAddress: String, baseStoragePath: String, attachments: [AttachmentDto]?) {
        self.init(
            id: status.stringId(),
            isLocal: status.isLocal,
            note: status.note,
            visibility: StatusVisibilityDto.from(status.visibility),
            sensitive: status.sensitive,
            contentWarning: status.contentWarning,
            commentsDisabled: status.commentsDisabled,
            replyToStatusId: status.replyToStatus?.stringId(),
            user: UserDto(from: status.user, flexiFields: [], baseStoragePath: baseStoragePath, baseAddress: baseAddress),
            attachments: attachments,
            tags: status.hashtags.map({ HashtagDto(url: "\(baseAddress)/discover/tags/\($0.hashtag)", name: $0.hashtag) }),
            baseAddress: baseAddress
        )
    }
}

extension StatusDto: Content { }
