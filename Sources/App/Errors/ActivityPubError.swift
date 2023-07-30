//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

enum ActivityPubError: Error {
    case missingSignatureHeader
    case missingSignedHeadersList
    case missingSignatureInHeader
    case missingSignedHeader(String)
    case signatureIsNotValid
    case singleActorIsSupportedInSigning
    case userNotExistsInDatabase
    case privateKeyNotExists
}

extension ActivityPubError: TerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .missingSignatureHeader: return "'Signature' header is missing."
        case .missingSignedHeadersList: return "Cannot read list of signed headers."
        case .missingSignatureInHeader: return "Cannot read signature in header."
        case .missingSignedHeader(let headerName): return "Cannot find header '\(headerName)' used to create signature."
        case .signatureIsNotValid: return "Signature is not valid."
        case .singleActorIsSupportedInSigning: return "Single actor is supported in signing."
        case .userNotExistsInDatabase: return "User cannot be found in the local database."
        case .privateKeyNotExists: return "Private key not found in local database."
        }
    }

    var identifier: String {
        return "activity-pub"
    }

    var code: String {
        switch self {
        case .missingSignatureHeader: return "missingSignatureHeader"
        case .missingSignedHeadersList: return "missingSignedHeadersList"
        case .missingSignatureInHeader: return "missingSignatureInHeader"
        case .missingSignedHeader: return "missingSignedHeader"
        case .signatureIsNotValid: return "signatureIsNotValid"
        case .singleActorIsSupportedInSigning: return "singleActorIsSupportedInSigning"
        case .userNotExistsInDatabase: return "userNotExistsInDatabase"
        case .privateKeyNotExists: return "privateKeyNotExists"
        }
    }
}
