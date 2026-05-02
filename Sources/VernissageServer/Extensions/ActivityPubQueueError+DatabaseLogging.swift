//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import ActivityPubKit

extension Error {
    var shouldStoreInDatabase: Bool {
        if let activityPubError = self as? ActivityPubError {
            switch activityPubError {
            case .signatureActorDoesNotMatchPayloadActor:
                // Ignore for now: either spoofing attempt or ActivityPub forwarding
                // (including reading signature from `proof`) that we will support later.
                return false
            case .domainIsBlockedByInstance:
                // Ignore blocked domain case because blocking is an intentional
                // moderation decision made by the instance user.
                return false
            case .actorIsBlockedByInstance:
                // Ignore blocked actor case because blocking is an intentional
                // moderation decision made by the instance user.
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
                    // Ignore 404 responses: when object does not exist remotely, there is
                    // no recovery action we can take by persisting this error.
                    return false
                }
            default:
                break
            }
        }

        if self.isConnectionError {
            // Ignore connection errors: if remote server is down/non-existent,
            // persisting this error will not help us recover automatically.
            return false
        }

        return true
    }
}
