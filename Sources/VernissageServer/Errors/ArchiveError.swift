//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during archive requests operations.
enum ArchiveError: String, Error {
    case requestWaitingForProcessing
    case processedRequestsAlereadyExist
    case missingEmail
    case missingFileName
}

extension ArchiveError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .forbidden
    }

    var reason: String {
        switch self {
        case .requestWaitingForProcessing: return "There is already a request waiting for processing."
        case .processedRequestsAlereadyExist: return "Processed request already exist."
        case .missingEmail: return "Missing user email."
        case .missingFileName: return "Missing archive file name."
        }
    }

    var identifier: String {
        return "archives"
    }

    var code: String {
        return self.rawValue
    }
}

