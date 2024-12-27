//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Archive status.
enum ArchiveStatus: Int, Codable {
    /// New archive requested.
    case `new` = 1
    
    /// System is creating new zip file with archive.
    case processing = 2
    
    /// Archive has been created successfully.
    case ready = 3
    
    /// Archive is old and not available now.
    case expired = 4
    
    /// Archive has not been created.
    case error = 5
}
