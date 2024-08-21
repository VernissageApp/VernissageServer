//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError
import ActivityPubKit

/// Errors returned during operations on checkpoints implementing the ActivityPub protocol.
enum ActivityPubError: Error {
    case missingSignatureHeader
    case missingSignedHeadersList
    case missingSignatureInHeader
    case missingSignedHeader(String)
    case signatureIsNotValid
    case singleActorIsSupportedInSigning
    case userNotExistsInDatabase(String)
    case privateKeyNotExists(String)
    case signatureDataNotCreated
    case missingDateHeader
    case incorrectDateFormat(String)
    case badTimeWindow(String)
    case followTypeNotSupported(ObjectTypeDto?)
    case acceptTypeNotSupported(ObjectTypeDto?)
    case rejectTypeNotSupported(ObjectTypeDto?)
    case algorithmNotSpecified
    case algorithmNotSupported(String)
    case missingSharedInboxUrl(String)
    case statusHasNotBeenDownloaded(String)
    case missingAttachments(String)
    case actorNotDownloaded(String)
    case invalidNoteUrl(String)
    case entityCaseError(String)
    case missingInstanceAdminAccount
    case missingInstanceAdminPrivateKey
    case unrecognizedActivityPubProfileUrl
    case domainIsBlockedByInstance(String)
}

extension ActivityPubError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .missingSignatureHeader: return "ActivityPub request 'Signature' header is missing."
        case .missingSignedHeadersList: return "Cannot read list of signed headers from ActivityPub request."
        case .missingSignatureInHeader: return "Cannot read signature in header in ActivityPub request."
        case .missingSignedHeader(let headerName): return "Cannot find header '\(headerName)' used to create signature in ActivityPub request."
        case .signatureIsNotValid: return "ActivityPub request signature is not valid."
        case .singleActorIsSupportedInSigning: return "Single actor is supported in ActivityPub request signing."
        case .userNotExistsInDatabase(let activityPubProfile): return "User '\(activityPubProfile)' cannot be found in the local database."
        case .privateKeyNotExists(let activityPubProfile): return "Private key not found in local database for user: '\(activityPubProfile)'."
        case .signatureDataNotCreated: return "Signature data cannot be created based on headers from request."
        case .missingDateHeader: return "ActivityPub request missing 'Date' header."
        case .incorrectDateFormat(let date): return "Incorrect date format in ActivityPub request: \(date)."
        case .badTimeWindow(let date): return "ActivityPub signed request date '\(date)' is outside acceptable time window."
        case .followTypeNotSupported(let type): return "Following object type: \(type?.rawValue ?? "<unknown>") is not supported."
        case .acceptTypeNotSupported(let type): return "Accepting object type: \(type?.rawValue ?? "<unknown>") is not supported."
        case .rejectTypeNotSupported(let type): return "Rejecting object type: \(type?.rawValue ?? "<unknown>") is not supported."
        case .algorithmNotSupported(let type): return "Algorithm: \(type) is not supported."
        case .algorithmNotSpecified: return "Algorithm is not specified."
        case .missingSharedInboxUrl(let activityPubProfile): return "Missing shared inbox in local database for user: '\(activityPubProfile)'."
        case .statusHasNotBeenDownloaded(let statusActivityPubUrl): return "Downloaded status is empty: \(statusActivityPubUrl)."
        case .missingAttachments(let statusActivityPubUrl): return "Downloaded status does not have image attachments: \(statusActivityPubUrl)."
        case .actorNotDownloaded(let statusActivityPubUrl): return "Error during downloading actor from remote server: \(statusActivityPubUrl)."
        case .invalidNoteUrl(let statusActivityPubUrl): return "Invalid URL to status: \(statusActivityPubUrl)."
        case .entityCaseError(let entityName): return "Cast to '\(entityName)' failed."
        case .missingInstanceAdminAccount: return "Missing admin account in local instance."
        case .missingInstanceAdminPrivateKey: return "Missing private key for admin account in local instance."
        case .unrecognizedActivityPubProfileUrl: return "Unrecognized ActivityPub profile URL."
        case .domainIsBlockedByInstance(let activityPubProfile): return "User's '\(activityPubProfile)' domain is blocked by the instance."
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
        case .signatureDataNotCreated: return "signatureDataNotCreated"
        case .missingDateHeader: return "missingDateHeader"
        case .incorrectDateFormat: return "incorrectDateFormat"
        case .badTimeWindow: return "badTimeWindow"
        case .followTypeNotSupported: return "followTypeNotSupported"
        case .acceptTypeNotSupported: return "acceptTypeNotSupported"
        case .rejectTypeNotSupported: return "rejectTypeNotSupported"
        case .algorithmNotSupported: return "algorithmNotSupported"
        case .algorithmNotSpecified: return "algorithmNotSpecified"
        case .missingSharedInboxUrl: return "missingSharedInboxUrl"
        case .statusHasNotBeenDownloaded: return "statusHasNotBeenDownloaded"
        case .missingAttachments: return "missingAttachments"
        case .actorNotDownloaded: return "actorNotDownloaded"
        case .invalidNoteUrl: return "invalidNoteUrl"
        case .entityCaseError: return "entityCaseError"
        case .missingInstanceAdminAccount: return "missingInstanceAdminAccount"
        case .missingInstanceAdminPrivateKey: return "missingInstanceAdminPrivateKey"
        case .unrecognizedActivityPubProfileUrl: return "unrecognizedActivityPubProfileUrl"
        case .domainIsBlockedByInstance: return "domainIsBlockedByInstance"
        }
    }
}

extension ActivityPubError: Equatable {
}
