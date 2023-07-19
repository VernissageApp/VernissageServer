//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct StatusDto {
    var id: String?
    var note: String
    var visibility: StatusVisibilityDto
    var sensitive: Bool
    var contentWarning: String?
    var commentsDisabled: Bool
    var replyToStatusId: String?
    var attachments: [AttachmentDto]?
}

extension StatusDto {
    init(from status: Status, attachments: [AttachmentDto]?) {
        self.init(
            id: status.stringId(),
            note: status.note,
            visibility: StatusVisibilityDto.from(status.visibility),
            sensitive: status.sensitive,
            contentWarning: status.contentWarning,
            commentsDisabled: status.commentsDisabled,
            replyToStatusId: status.replyToStatus?.stringId(),
            attachments: attachments
        )
    }
}

extension StatusDto: Content { }
