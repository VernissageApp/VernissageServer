//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Information about single ActivityPub message connected with status.
struct StatusActivityPubEventItemDto {
    var id: String?
    var url: String
    var isSuccess: Bool?
    var errorMessage: String?
    var startAt: Date?
    var endAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
}

/// Allows `StatusActivityPubEventItemDto` to be encoded to and decoded from HTTP messages.
extension StatusActivityPubEventItemDto: Content { }
