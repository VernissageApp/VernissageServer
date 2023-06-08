//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum StorageError: Error {
    case notSuccessResponse(ClientResponse)
    case notSupportedStorage
    case emptyBody
    case emptyPublicFolderPath
    case unknownError
}

extension StorageError: TerminateError {
    var status: HTTPResponseStatus {
        return .internalServerError
    }

    var reason: String {
        switch self {
        case .notSuccessResponse: return "It's error returned from remote server."
        case .notSupportedStorage: return "Storage system is not supported yet."
        case .emptyBody: return "External system returned empty body."
        case .emptyPublicFolderPath: return "Public folder name is not specified."
        case .unknownError: return "Response doesn't contains any information about request status."
        }
    }

    var identifier: String {
        return "storage"
    }

    var code: String {
        switch self {
        case .notSuccessResponse: return "notSuccessResponse"
        case .notSupportedStorage: return "notSupportedStorage"
        case .emptyBody: return "emptyBody"
        case .emptyPublicFolderPath: return "emptyPublicFolderPath"
        case .unknownError: return "unknownError"
        }
    }
}

