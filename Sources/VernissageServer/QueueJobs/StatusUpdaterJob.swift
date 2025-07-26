//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

/// Background job for sending updated status to remote server.
struct StatusUpdaterJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("StatusUpdaterJob dequeued job. Status (id: '\(payload)').")

        let statusesService = context.application.services.statusesService
        try await statusesService.send(update: payload, on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        await context.logger.store("StatusUpdaterJob error. Status (id: '\(payload)').", error, on: context.application)
    }
}
