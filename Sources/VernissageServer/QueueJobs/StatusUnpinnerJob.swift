//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues

/// Background job for sending `Remove` to remote featured collections.
struct StatusUnpinnerJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("StatusUnpinnerJob dequeued job. Status unpin (id: '\(payload)').")

        let collectionsService = context.application.services.collectionsService
        try await collectionsService.sendRemoveFromFeatured(for: payload, on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        await context.logger.store("StatusUnpinnerJob error. Status unpin (id: '\(payload)').", error, on: context.application)
    }
}
