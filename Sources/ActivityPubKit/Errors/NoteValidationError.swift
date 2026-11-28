//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

enum NoteValidationError: LocalizedError, Equatable {
    case responseOriginMismatch
    case objectIdMismatch
    case authorOriginMismatch

    var errorDescription: String? {
        switch self {
        case .responseOriginMismatch:
            "The note response came from a different origin than the requested URL."
        case .objectIdMismatch:
            "The declared note ID differs from the requested URL."
        case .authorOriginMismatch:
            "The declared author and the note must have the same origin."
        }
    }
}
