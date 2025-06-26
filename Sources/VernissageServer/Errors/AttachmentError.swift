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
    case createResizedImageFailed
    case imageRotationFailed
    case imageResizeFailed
    case attachmentAlreadyConnectedToStatus
    case imageTooLarge
    case onlyAvifHdrFilesAreSupported
    case emailNotVerified
}

extension AttachmentError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .missingImage, .attachmentAlreadyConnectedToStatus, .onlyAvifHdrFilesAreSupported, .emailNotVerified: return .badRequest
        case .createResizedImageFailed, .imageRotationFailed, .imageResizeFailed: return .internalServerError
        case .imageTooLarge: return .payloadTooLarge
        }
    }

    var reason: String {
        switch self {
        case .missingImage: return "Image is not attached into the request."
        case .createResizedImageFailed: return "Cannot create image for resizing."
        case .imageRotationFailed: return "Image cannot be rotated."
        case .imageResizeFailed: return "Image cannot be resized."
        case .attachmentAlreadyConnectedToStatus: return "Attachment already connected to status."
        case .imageTooLarge: return "Image file is too large."
        case .onlyAvifHdrFilesAreSupported: return "Only AVIF HDR files are supported."
        case .emailNotVerified: return "User email has not been verified."
        }
    }

    var identifier: String {
        return "attachment"
    }

    var code: String {
        return self.rawValue
    }
}
