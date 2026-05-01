//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import ActivityPubKit

extension Error {
    var shouldStoreInDatabase: Bool {
        if let activityPubError = self as? ActivityPubError {
            switch activityPubError {
            case .signatureActorDoesNotMatchPayloadActor:
                return false
            case .statusHasNotBeenDownloaded:
                return false
            default:
                break
            }
        }

        if let networkError = self as? NetworkError {
            switch networkError {
            case .notSuccessResponse(let response, _):
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 404 {
                    return false
                }
            default:
                break
            }
        }

        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotFindHost {
            return false
        }

        if nsError.domain == NSURLErrorDomain &&
            nsError.code == NSURLErrorUnknown &&
            nsError.localizedDescription.contains("HTTP/2 stream") &&
            nsError.localizedDescription.contains("INTERNAL_ERROR") {
            return false
        }

        return true
    }
}
