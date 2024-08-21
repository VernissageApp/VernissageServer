//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Errors returned during push subscriptions operations.
enum PushSubscriptionError: String, Error {
    case incorrectPushSubscriptionId
}

extension PushSubscriptionError: LocalizedTerminateError {
    var status: HTTPResponseStatus {
        return .badRequest
    }

    var reason: String {
        switch self {
        case .incorrectPushSubscriptionId: return "Push subscription id is incorrect."
        }
    }

    var identifier: String {
        return "push-subscription"
    }

    var code: String {
        return self.rawValue
    }
}
