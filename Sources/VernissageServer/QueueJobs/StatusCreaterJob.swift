//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

/// Background job for sending status to remote server.
struct StatusCreaterJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("StatusCreaterJob dequeued job. Status (id: '\(payload)').")

        let statusesService = context.application.services.statusesService
        try await statusesService.send(status: payload, on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        await context.logger.store("StatusCreaterJob error. Status (id: '\(payload)').", error, on: context.application)
    }
}
