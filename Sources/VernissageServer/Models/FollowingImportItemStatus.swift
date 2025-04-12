//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Status of following import item (account).
enum FollowingImportItemStatus: Int, Codable {
    /// Item has not been processed yet.
    case notProcessed = 1
    
    /// Account is in the local instance (is not remote) and has been followed.
    case followed = 2
    
    /// Account is remote account and we sent the follow request.
    case sent = 3
    
    /// Account is remote account and we've got the error message during sending the HTTP request.
    case error = 4
}
