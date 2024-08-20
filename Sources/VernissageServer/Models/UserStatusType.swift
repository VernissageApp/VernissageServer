//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// User's status type.
enum UserStatusType: Int, Codable {
    /// Status added by owner.
    case owner = 1

    /// Status added by followed user.
    case follow = 2
    
    /// Status rebloged by followed user.
    case reblog = 3
    
    /// Status added by mention.
    case mention = 4
}
