//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues

/// Background job for sending user profile updates to remote mutual follows.
struct ActivityPubProfileUpdateJob: AsyncJob {
    typealias Payload = ActivityPubProfileUpdateJobDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubProfileUpdateJobDto) async throws {
        context.logger.info("ActivityPubProfileUpdateJob dequeued job. User id: '\(payload.userId)'.")
        
        let activityPubProfileUpdateService = context.application.services.activityPubProfileUpdateService
        try await activityPubProfileUpdateService.send(userId: payload.userId, on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubProfileUpdateJobDto) async throws {
        await context.logger.store("ActivityPubProfileUpdateJob error. User id: '\(payload.userId)'.", error, on: context.application)
    }
}
