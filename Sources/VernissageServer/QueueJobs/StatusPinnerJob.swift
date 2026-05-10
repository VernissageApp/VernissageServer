//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues

/// Background job for sending `Add` to remote featured collections.
struct StatusPinnerJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("StatusPinnerJob dequeued job. Status pin (id: '\(payload)').")

        let statusesService = context.application.services.statusesService
        try await statusesService.send(pin: payload, on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        await context.logger.store("StatusPinnerJob error. Status pin (id: '\(payload)').", error, on: context.application)
    }
}
