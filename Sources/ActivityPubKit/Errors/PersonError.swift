//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public enum PersonError: Error {
    case missingUrl
}

extension PersonError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingUrl:
            return NSLocalizedString("person.error.missingUrl",
                                     bundle: Bundle.module,
                                     comment: "Missing person URL. At least one person URL is required.")
        }
    }
}
