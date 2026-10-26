//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Errors returned during direct-message operations.
enum DirectMessageError: String, LocalizedTerminateError {
    case unsupportedStatusOperation
    case invalidId
    case invalidPagination
    case recipientsRequired
    case emptyMessage
    case messageTooLong
    case recipientUnavailable
    case conversationNotFound
    case messageNotFound
    case invalidReply
    case invalidReadSelection
    case sqlDatabaseRequired

    var status: HTTPResponseStatus {
        switch self {
        case .conversationNotFound, .messageNotFound: return .notFound
        case .recipientUnavailable, .unsupportedStatusOperation: return .forbidden
        case .sqlDatabaseRequired: return .internalServerError
        default: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .unsupportedStatusOperation: return "Direct messages cannot be edited through photo status endpoints."
        case .invalidId: return "Invalid direct-message identifier."
        case .invalidPagination: return "Page must be positive and size must be between 1 and 100."
        case .recipientsRequired: return "At least one recipient other than the author is required (maximum 100)."
        case .emptyMessage: return "A direct message must contain text or an attachment."
        case .messageTooLong: return "Direct message exceeds the configured character limit."
        case .recipientUnavailable: return "A recipient is unavailable or blocks communication with the author."
        case .conversationNotFound: return "Direct conversation not found."
        case .messageNotFound: return "Direct message not found."
        case .invalidReply: return "The reply must reference an accessible message in this conversation."
        case .invalidReadSelection: return "Read selection must contain 1 to 100 accessible message identifiers."
        case .sqlDatabaseRequired: return "Direct-message pagination requires SQL."
        }
    }

    var code: String {
        return rawValue
    }

    var parameters: [String: String]? {
        return nil
    }

    var identifier: String {
        "directMessage"
    }
}
