//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during operations on attachments.
enum AttachmentError: String, Error {
    case missingImage
    case savedFailed
    case createResizedImageFailed
    case resizedImageFailed
    case attachmentAlreadyConnectedToStatus
    case imageTooLarge
}

extension AttachmentError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .missingImage, .attachmentAlreadyConnectedToStatus: return .badRequest
        case .savedFailed, .createResizedImageFailed, .resizedImageFailed: return .internalServerError
        case .imageTooLarge: return .payloadTooLarge
        }
    }

    var reason: String {
        switch self {
        case .missingImage: return "Image is not attached into the request."
        case .savedFailed: return "Saving file failed."
        case .createResizedImageFailed: return "Cannot create image for resizing."
        case .resizedImageFailed: return "Image cannot be resized."
        case .attachmentAlreadyConnectedToStatus: return "Attachment already connected to status."
        case .imageTooLarge: return "Image file is too large."
        }
    }

    var identifier: String {
        return "attachment"
    }

    var code: String {
        return self.rawValue
    }
}
