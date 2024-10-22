//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Source of error.
enum ErrorItemSource: Int, Codable {
    /// Errors registered from client.
    case client = 1
    
    /// Errors registered by server.
    case server = 2
}
