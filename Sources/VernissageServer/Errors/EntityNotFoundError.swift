//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned when the specified object does not exist in the database.
enum EntityNotFoundError: String, Error {
    case userNotFound
    case refreshTokenNotFound
    case roleNotFound
    case authClientNotFound
    case attachmentNotFound
    case statusNotFound
    case locationNotFound
    case invitationNotFound
    case reportNotFound
    case twoFactorTokenNotFound
    case instanceBlockedDomainNotFound
    case pushSubscriptionNotFound
    case ruleNotFound
    case errorItemNotFound
    case userAliasNotFound
    case archiveNotFound
    case userSettingNotFound
    case categoryNotFound
    case followingImportNotFound
    case articleNotFound
    case businessCardNotFound
    case sharedBusinessCardNotFound
}

extension EntityNotFoundError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .notFound
    }

    var reason: String {
        switch self {
        case .userNotFound: return "User not exists."
        case .refreshTokenNotFound: return "Refresh token not exists."
        case .roleNotFound: return "Role not exists."
        case .authClientNotFound: return "Authentication client not exists."
        case .attachmentNotFound: return "Attachment not exists."
        case .statusNotFound: return "Status not exists."
        case .locationNotFound: return "Location not exists."
        case .invitationNotFound: return "Invitation not exists."
        case .reportNotFound: return "Report not exists."
        case .twoFactorTokenNotFound: return "Two factor token not exists."
        case .instanceBlockedDomainNotFound: return "Instance blocked domain not exists."
        case .pushSubscriptionNotFound: return "Push subscription not exists."
        case .ruleNotFound: return "Rule not exists."
        case .errorItemNotFound: return "Error item not exists."
        case .userAliasNotFound: return "User alias not exists."
        case .archiveNotFound: return "Archive not exists."
        case .userSettingNotFound: return "User setting not exists."
        case .categoryNotFound: return "Category not exists."
        case .followingImportNotFound: return "Following import not exists."
        case .articleNotFound: return "Article not exists."
        case .businessCardNotFound: return "Business card not exists."
        case .sharedBusinessCardNotFound: return "Shared business card not exists."
        }
    }

    var identifier: String {
        return "entity-not-found"
    }

    var code: String {
        return self.rawValue
    }
}
