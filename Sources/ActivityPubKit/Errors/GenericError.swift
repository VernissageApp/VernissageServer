//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public enum GenericError: Error {
    case missingPrivateKey
    case missingUserAgent
    case missingHost
}

extension GenericError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingPrivateKey:
            return NSLocalizedString("global.error.missingPrivateKey",
                                     bundle: Bundle.module,
                                     comment: "Missing private key. Signature cannot be generated.")
        case .missingUserAgent:
            return NSLocalizedString("global.error.missingUserAgent",
                                     bundle: Bundle.module,
                                     comment: "Missing user agent. Signature cannot be generated.")
        case .missingHost:
            return NSLocalizedString("global.error.missingHost",
                                     bundle: Bundle.module,
                                     comment: "Missing host. Signature cannot be generated.")
        }
    }
}
