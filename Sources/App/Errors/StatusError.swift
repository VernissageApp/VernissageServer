//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum StatusError: String, Error {
    case incorrectStatusId
    case attachmentsAreRequired
    case incorrectAttachmentId
}

extension StatusError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectStatusId: return "Status id is incorrect."
        case .attachmentsAreRequired: return "Attachments are misssing."
        case .incorrectAttachmentId: return "Incorrect attachment id."
        }
    }

    var identifier: String {
        return "status"
    }

    var code: String {
        return self.rawValue
    }
}