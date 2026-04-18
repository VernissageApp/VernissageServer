//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues

/// Background job responsible for forwarding local reports as ActivityPub Flag activities.
struct FlagCreaterJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("FlagCreaterJob dequeued job. Report (id: '\(payload)').")
        let reportsService = context.application.services.reportsService
        try await reportsService.send(reportId: payload, on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        await context.logger.store("FlagCreaterJob error. Report (id: '\(payload)').", error, on: context.application)
    }
}
