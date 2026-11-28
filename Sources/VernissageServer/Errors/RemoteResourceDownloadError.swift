//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum RemoteResourceDownloadError: LocalizedError, Equatable {
    case invalidURL
    case unresolvedHost
    case nonPublicAddress
    case invalidRedirect
    case tooManyRedirects

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The remote resource must have a valid HTTP or HTTPS URL."
        case .unresolvedHost: "The remote resource host could not be resolved."
        case .nonPublicAddress: "The remote resource host has a non-public address."
        case .invalidRedirect: "The remote resource returned an invalid redirect."
        case .tooManyRedirects: "The remote resource returned too many redirects."
        }
    }
}
