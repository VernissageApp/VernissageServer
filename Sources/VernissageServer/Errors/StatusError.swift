//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during status operations.
enum StatusError: String, Error {
    case incorrectStatusId
    case attachmentsAreRequired
    case incorrectAttachmentId
    case cannotReblogMentionedStatus
    case cannotReblogComments
    case cannotAddCommentWithoutCommentedStatus
}

extension StatusError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .cannotReblogMentionedStatus, .cannotReblogComments:
            return .forbidden
        default:
            return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .incorrectStatusId: return "Status id is incorrect."
        case .attachmentsAreRequired: return "Attachments are misssing."
        case .incorrectAttachmentId: return "Incorrect attachment id."
        case .cannotReblogMentionedStatus: return "Cannot reblog status with mentioned visibility."
        case .cannotReblogComments: return "Cannot reblog comments."
        case .cannotAddCommentWithoutCommentedStatus: return "Cannot add comment without commented status."
        }
    }

    var identifier: String {
        return "status"
    }

    var code: String {
        return self.rawValue
    }
}
