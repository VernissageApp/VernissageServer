//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public enum SerializationError: Error {
    case notSupportedObjectType(ObjectTypeDto)
}

extension SerializationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notSupportedObjectType(_):
            return NSLocalizedString("global.error.notSupportedObjectType",
                                     bundle: Bundle.module,
                                     comment: "Not supported object type in the deserialization.")
        }
    }
}
