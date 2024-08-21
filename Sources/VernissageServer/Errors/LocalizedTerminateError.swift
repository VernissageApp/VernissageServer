//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ExtendedError

/// Base protocol error for all errors returned in the system.
/// Thanks to that error we have localized errors in the console and int the database.
protocol LocalizedTerminateError: TerminateError, LocalizedError {
}

extension LocalizedTerminateError {
    var errorDescription: String? {
        return "The operation couldn’t be completed. Error type: '\(String(reflecting: self))'. Error message: \(self.reason)"
    }
}
