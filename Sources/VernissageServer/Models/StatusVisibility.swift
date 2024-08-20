//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Status visibility.
enum StatusVisibility: Int, Codable {
    /// All users can see the status.
    /// Status is visible on all timelines and on user profile page when other user opens profile.
    case `public` = 1
    
    /// Only followers can see the status on their timelines.
    /// Status is visible on profile page for owner, other people canot see status on user's profile page.
    case followers = 2
    
    /// Only mentioned users can see the status on their timelines.
    /// Status is visible on profile page for owner, other people cannot see status on user's profile page.
    case mentioned = 3
}
