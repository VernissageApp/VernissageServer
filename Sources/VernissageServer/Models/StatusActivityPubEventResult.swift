//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// ActivityPub status integration result.
enum StatusActivityPubEventResult: Int, Codable {
    /// New event waiting for processing.
    case waiting = 1
    
    /// Event is processing by job.
    case processing = 2
    
    /// Event has been successfully processed by job.
    /// There wasn't any errors during sending information to remote instances.
    case finished = 3
    
    /// Event has been successfully processed by job.
    /// During processing some instances returned errors or didn't response at all.
    case finishedWithErrors = 4
    
    /// Event has not been processed by job because of critical error.
    case failed = 5
}
