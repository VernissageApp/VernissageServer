//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

public enum CacheableError: Error, CustomStringConvertible {
    case message(String)
    
    public var description: String {
        switch self {
        case .message(let msg):
            return msg
        }
    }
}
