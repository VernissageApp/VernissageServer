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
struct ActivityPubStatusJob: RetryableAsyncJob {
    typealias Payload = ActivityPubStatusJobDataDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubStatusJobDataDto) async throws {
        context.logger.info("ActivityPubStatusJob dequeued job. Status event (id: '\(payload.statusActivityPubEventId)').")

        // Get status event to proceed.
        guard let statusActivityPubEvent = try await StatusActivityPubEvent.query(on: context.application.db)
            .with(\.$status)
            .with(\.$user)
            .with(\.$statusActivityPubEventItems)
            .filter(\.$id == payload.statusActivityPubEventId)
            .first() else {
            return
        }

        let activityPubOutgoingStatusService = context.application.services.activityPubOutgoingStatusService
        switch statusActivityPubEvent.type {
        case .create:
            try await activityPubOutgoingStatusService.create(statusActivityPubEvent: statusActivityPubEvent,
                                                              on: context.executionContext)
        case .update:
            try await activityPubOutgoingStatusService.update(statusActivityPubEvent: statusActivityPubEvent,
                                                              on: context.executionContext)
        case .like:
            try await activityPubOutgoingStatusService.like(statusActivityPubEvent: statusActivityPubEvent,
                                                            statusFavouriteId: payload.statusFavouriteId,
                                                            on: context.executionContext)
        case .unlike:
            try await activityPubOutgoingStatusService.unlike(statusActivityPubEvent: statusActivityPubEvent,
                                                              statusFavouriteId: payload.statusFavouriteId,
                                                              on: context.executionContext)
        case .announce:
            try await activityPubOutgoingStatusService.announce(statusActivityPubEvent: statusActivityPubEvent,
                                                                activityPubReblog: payload.activityPubReblog,
                                                                on: context.executionContext)
        case .unannounce:
            try await activityPubOutgoingStatusService.unannounce(statusActivityPubEvent: statusActivityPubEvent,
                                                                  activityPubUnreblog: payload.activityPubUnreblog,
                                                                  on: context.executionContext)
        case .pin:
            try await activityPubOutgoingStatusService.pin(statusActivityPubEvent: statusActivityPubEvent,
                                                           on: context.executionContext)
        case .unpin:
            try await activityPubOutgoingStatusService.unpin(statusActivityPubEvent: statusActivityPubEvent,
                                                             on: context.executionContext)
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubStatusJobDataDto) async throws {
        await context.logger.store("ActivityPubStatusJob error. Status event (id: '\(payload.statusActivityPubEventId)').", error, on: context.application)
    }
}
