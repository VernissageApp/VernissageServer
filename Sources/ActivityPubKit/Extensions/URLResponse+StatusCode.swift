//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension URLResponse {
    func statusCode() -> HTTPStatusCode? {
        let statusCode = (self as? HTTPURLResponse)?.status
        return statusCode
    }
}
