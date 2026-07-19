//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createTimelineMarker(user: User, status: Status, timeline: TimelineKind) async throws -> TimelineMarker {
        let id = await ApplicationManager.shared.generateId()
        let timelineMarker = try TimelineMarker(
            id: id,
            statusId: status.requireID(),
            userId: user.requireID(),
            timeline: timeline
        )

        try await timelineMarker.save(on: self.db)
        return timelineMarker
    }
}
