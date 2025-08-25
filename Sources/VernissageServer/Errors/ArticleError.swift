//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during articles operations.
enum ArticleError: String, Error {
    case incorrectArticleId
    case incorrectArticleFileId
    case missingFile
    case imageTooLarge
    case fileTypeNotSupported
    case fileConnectedWithDifferentArticle
}

extension ArticleError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectArticleId: return "Incorrect article id."
        case .incorrectArticleFileId: return "Incorrect article file id."
        case .missingFile: return "The file is missing."
        case .imageTooLarge: return "Image is too large."
        case .fileTypeNotSupported: return "File type is not supported."
        case .fileConnectedWithDifferentArticle: return "File is connected to different article."
        }
    }

    var identifier: String {
        return "article"
    }

    var code: String {
        return self.rawValue
    }
}
