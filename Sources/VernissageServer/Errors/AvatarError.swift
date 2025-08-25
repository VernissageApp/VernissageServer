//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during operations on avatars.
enum AvatarError: String, Error {
    case missingImage
    case notFound
    case createResizedImageFailed
    case resizedImageFailed
    case userNameIsRequired
}

extension AvatarError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .missingImage, .notFound, .userNameIsRequired: return .badRequest
        case .resizedImageFailed, .createResizedImageFailed: return .internalServerError
        }
    }

    var reason: String {
        switch self {
        case .missingImage: return "Image is not attached into the request."
        case .notFound: return "User doesn't have any avatar."
        case .createResizedImageFailed: return "Cannot create image for resizing."
        case .resizedImageFailed: return "Image cannot be resized."
        case .userNameIsRequired: return "User name is required."
        }
    }

    var identifier: String {
        return "avatar"
    }

    var code: String {
        return self.rawValue
    }
}
