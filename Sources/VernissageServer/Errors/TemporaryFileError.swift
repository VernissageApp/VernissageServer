//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum TemporaryFileError: String, Error {
    case temporaryUrlFailed
}

extension TemporaryFileError: TerminateError {
    var status: HTTPResponseStatus {
        return .internalServerError
    }

    var reason: String {
        switch self {
        case .temporaryUrlFailed: return "Temporary URL cannot be created."
        }
    }

    var identifier: String {
        return "temporaryFile"
    }

    var code: String {
        return self.rawValue
    }
}