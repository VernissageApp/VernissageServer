//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Status of following users import.
enum FollowingImportStatus: Int, Codable {
    /// Following import is new and not processed.
    case new = 1
    
    /// Following import is during processing.
    case processing = 2
    
    /// Following import finished.
    case finished = 3
}
