//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct StatusRequestDto {
    var note: String
    var visibility: StatusVisibilityDto
    var sensitive: Bool
    var contentWarning: String?
    var commentsDisabled: Bool
    var replyToStatusId: String?
    var attachmentIds: [String]
}

extension StatusRequestDto: Content { }

extension StatusRequestDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("contentWarning", as: String?.self, is: .count(...100) || .nil, required: false)
    }
}
