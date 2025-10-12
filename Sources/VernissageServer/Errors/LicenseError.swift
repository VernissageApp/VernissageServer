//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during license operations.
enum LicenseError: String, Error {
    case incorrectLicenseId
    case licenseAlreadyInUse
}

extension LicenseError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        switch self {
        case .incorrectLicenseId: return .badRequest
        case .licenseAlreadyInUse: return .forbidden
        }
    }

    var reason: String {
        switch self {
        case .incorrectLicenseId: return "License id is incorrect."
        case .licenseAlreadyInUse: return "License is already in use."
        }
    }

    var identifier: String {
        return "license"
    }

    var code: String {
        return self.rawValue
    }
}
