//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Content for standard status creation and updates. Mentioned visibility and direct-message parents are rejected.
/// Use `DirectMessageRequestDto` with the direct-message endpoints to send messages to explicit recipients.
struct StatusRequestDto {
    var note: String
    var visibility: StatusVisibilityDto
    var sensitive: Bool
    var contentWarning: String?
    var commentsDisabled: Bool
    var categoryId: String?
    var replyToStatusId: String?
    var attachmentIds: [String]
}

extension StatusRequestDto: Content { }

extension StatusRequestDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("contentWarning", as: String?.self, is: .count(...100) || .nil, required: false)
    }
}
