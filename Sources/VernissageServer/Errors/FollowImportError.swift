//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during importing followers operation.
enum FollowImportError: String, Error {
    case missingFile
    case emptyFile
    case accountNotFound
}

extension FollowImportError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .missingFile: return "Missing file with accounts."
        case .emptyFile: return "File with accounts is empty."
        case .accountNotFound: return "Account not found."
        }
    }

    var identifier: String {
        return "follow-imports"
    }

    var code: String {
        return self.rawValue
    }
}

