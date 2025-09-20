//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor
import ActivityPubKit

/// Information about single ActivityPub events connected with status.
struct StatusActivityPubEventDto {
    var id: String?
    var user: UserDto
    var type: StatusActivityPubEventTypeDto
    var result: StatusActivityPubEventResultDto
    var errorMessage: String?
    var attempts: Int
    var startAt: Date?
    var endAt: Date?
    var createdAt: Date?
    var updatedAt: Date?
    var statusActivityPubEventItems: [StatusActivityPubEventItemDto]?
}

/// Allows `StatusActivityPubEventDto` to be encoded to and decoded from HTTP messages.
extension StatusActivityPubEventDto: Content { }
