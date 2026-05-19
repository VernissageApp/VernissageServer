//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

public protocol TerminateError: AbortError {
    var identifier: String { get }
    var code: String { get }
    var parameters: [String: String]? { get }
}
