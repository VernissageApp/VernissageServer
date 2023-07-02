//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum HeaderError: String, Error {
    case missingImage
    case notFound
    case savedFailed
}

extension HeaderError: TerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .missingImage, .notFound: return .badRequest
        case .savedFailed: return .internalServerError
        }
    }

    var reason: String {
        switch self {
        case .missingImage: return "Image is not attached into the request."
        case .notFound: return "User doesn't have any header."
        case .savedFailed: return "Saving file failed."
        }
    }

    var identifier: String {
        return "avatar"
    }

    var code: String {
        return self.rawValue
    }
}
