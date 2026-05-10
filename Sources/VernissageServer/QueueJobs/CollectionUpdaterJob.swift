//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues

/// Background job for synchronizing remote user featured collection.
struct CollectionUpdaterJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("CollectionUpdaterJob dequeued job. User id: '\(payload)'.")

        let collectionsService = context.application.services.collectionsService
        try await collectionsService.synchronizeFeaturedCollection(for: payload, on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        await context.logger.store("CollectionUpdaterJob error. User id: '\(payload)'.", error, on: context.application)
    }
}
