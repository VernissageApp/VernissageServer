//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// Last status watched by a user on a specific timeline.
final class TimelineMarker: Model, @unchecked Sendable {
    static let schema: String = "TimelineMarkers"

    @ID(custom: .id, generatedBy: .user)
    var id: Int64?

    @Parent(key: "statusId")
    var status: Status

    @Parent(key: "userId")
    var user: User

    @Field(key: "timeline")
    var timeline: TimelineKind

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    var updatedAt: Date?

    init() { }

    convenience init(id: Int64, statusId: Int64, userId: Int64, timeline: TimelineKind) {
        self.init()

        self.id = id
        self.$status.id = statusId
        self.$user.id = userId
        self.timeline = timeline
    }
}

/// Allows `TimelineMarker` to be encoded to and decoded from HTTP messages.
extension TimelineMarker: Content { }
