//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Type of a follow-related ActivityPub request created during account migration.
enum MigrationFollowActivityPubEventItemType: Int, Codable {
    /// Sends a Follow activity to the target account.
    case follow = 1

    /// Sends an Undo Follow activity to the source account.
    case unfollow = 2
}
