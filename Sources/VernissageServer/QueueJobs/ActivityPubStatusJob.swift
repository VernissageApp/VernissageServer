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

        let activityPubService = context.application.services.activityPubService
        switch statusActivityPubEvent.type {
        case .create:
            try await activityPubService.create(statusActivityPubEvent: statusActivityPubEvent,
                                                on: context.executionContext)
        case .update:
            try await activityPubService.update(statusActivityPubEvent: statusActivityPubEvent,
                                                on: context.executionContext)
        case .like:
            try await activityPubService.like(statusActivityPubEvent: statusActivityPubEvent,
                                              statusFavouriteId: payload.statusFavouriteId,
                                              on: context.executionContext)
        case .unlike:
            try await activityPubService.unlike(statusActivityPubEvent: statusActivityPubEvent,
                                                statusFavouriteId: payload.statusFavouriteId,
                                                on: context.executionContext)
        case .announce:
            try await activityPubService.announce(statusActivityPubEvent: statusActivityPubEvent,
                                                  activityPubReblog: payload.activityPubReblog,
                                                  on: context.executionContext)
        case .unannounce:
            try await activityPubService.unannounce(statusActivityPubEvent: statusActivityPubEvent,
                                                    activityPubUnreblog: payload.activityPubUnreblog,
                                                    on: context.executionContext)
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubStatusJobDataDto) async throws {
        await context.logger.store("ActivityPubStatusJob error. Status event (id: '\(payload.statusActivityPubEventId)').", error, on: context.application)
    }
}
