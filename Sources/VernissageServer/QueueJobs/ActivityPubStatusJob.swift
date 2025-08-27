//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import FluentSQL
import Queues

/// Background job for sending status events to remote server.
struct ActivityPubStatusJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("ActivityPubStatusJob dequeued job. Status event (id: '\(payload)').")

        let activityPubService = context.application.services.activityPubService
        
        // Get status event to proceed.
        guard let statusActivityPubEvent = try await StatusActivityPubEvent.query(on: context.application.db)
            .with(\.$status)
            .with(\.$user)
            .with(\.$statusActivityPubEventItems)
            .filter(\.$id == payload)
            .first() else {
            return
        }
        
        switch statusActivityPubEvent.type {
        case .create:
            try await activityPubService.create(statusActivityPubEvent: statusActivityPubEvent, on: context.executionContext)
        case .update:
            try await activityPubService.update(statusActivityPubEvent: statusActivityPubEvent, on: context.executionContext)
        default:
            context.logger.info("Unhandled action type: '\(statusActivityPubEvent.type)'.")
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        await context.logger.store("ActivityPubStatusJob error. Status event (id: '\(payload)').", error, on: context.application)
    }
}
