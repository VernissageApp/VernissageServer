//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
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
    case cannotDeleteStatus
    case cannotUpdateOtherUserStatus
    case sortColumnNotSupported
    case incorrectStatusEventId
    case maxLimitOfAttachmentsExceeded
}

extension StatusError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .cannotReblogMentionedStatus, .cannotReblogComments, .cannotUpdateOtherUserStatus, .maxLimitOfAttachmentsExceeded:
            return .forbidden
        case .cannotDeleteStatus:
            return .internalServerError
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
        case .cannotDeleteStatus: return "Error occurred while deleting status."
        case .cannotUpdateOtherUserStatus: return "Cannot update other user status."
        case .sortColumnNotSupported: return "Sort column is not supported."
        case .incorrectStatusEventId: return "Incorrect status event id."
        case .maxLimitOfAttachmentsExceeded: return "Maximum limit of attachments exceeded"
        }
    }

    var identifier: String {
        return "status"
    }

    var code: String {
        return self.rawValue
    }
}
