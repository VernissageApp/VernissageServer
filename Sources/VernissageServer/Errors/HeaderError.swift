//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during operations on header.
enum HeaderError: String, Error {
    case missingImage
    case notFound
    case savedFailed
    case createResizedImageFailed
    case resizedImageFailed
}

extension HeaderError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .missingImage, .notFound: return .badRequest
        case .savedFailed, .resizedImageFailed, .createResizedImageFailed: return .internalServerError
        }
    }

    var reason: String {
        switch self {
        case .missingImage: return "Image is not attached into the request."
        case .notFound: return "User doesn't have any header."
        case .savedFailed: return "Saving file failed."
        case .createResizedImageFailed: return "Cannot create image for resizing."
        case .resizedImageFailed: return "Image cannot be resized."
        }
    }

    var identifier: String {
        return "avatar"
    }

    var code: String {
        return self.rawValue
    }
}
