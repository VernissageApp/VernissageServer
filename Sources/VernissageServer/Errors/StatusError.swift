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
    case emailNotVerified
    case accountHasBeenMoved
    case cannotReblogMentionedStatus
    case cannotReblogComments
    case cannotAddCommentWithoutCommentedStatus
    case cannotDeleteStatus
    case cannotUpdateOtherUserStatus
    case cannotPinNonPublicStatus
    case cannotPinComment
    case cannotPinReblog
    case sortColumnNotSupported
    case incorrectStatusEventId
    case maxLimitOfAttachmentsExceeded
    case statusCreationTooFrequent
}

extension StatusError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .accountHasBeenMoved, .emailNotVerified, .cannotReblogMentionedStatus, .cannotReblogComments, .cannotUpdateOtherUserStatus, .maxLimitOfAttachmentsExceeded, .cannotPinNonPublicStatus, .cannotPinComment, .cannotPinReblog:
            return .forbidden
        case .statusCreationTooFrequent:
            return .tooManyRequests
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
        case .emailNotVerified: return "User email has not been verified."
        case .accountHasBeenMoved: return "Account has been moved and cannot create new statuses."
        case .cannotReblogMentionedStatus: return "Cannot reblog status with mentioned visibility."
        case .cannotReblogComments: return "Cannot reblog comments."
        case .cannotAddCommentWithoutCommentedStatus: return "Cannot add comment without commented status."
        case .cannotDeleteStatus: return "Error occurred while deleting status."
        case .cannotUpdateOtherUserStatus: return "Cannot update other user status."
        case .cannotPinNonPublicStatus: return "Cannot pin non-public status."
        case .cannotPinComment: return "Cannot pin comments."
        case .cannotPinReblog: return "Cannot pin reblogs."
        case .sortColumnNotSupported: return "Sort column is not supported."
        case .incorrectStatusEventId: return "Incorrect status event id."
        case .maxLimitOfAttachmentsExceeded: return "Maximum limit of attachments exceeded"
        case .statusCreationTooFrequent: return "New status cannot be created yet. Please wait before adding another one."
        }
    }

    var identifier: String {
        return "status"
    }

    var code: String {
        return self.rawValue
    }
}
