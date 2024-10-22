//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

/// Background job for reblog status.
struct StatusRebloggerJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("StatusRebloggerJob dequeued job. Status (id: '\(payload)').")

        let statusesService = context.application.services.statusesService
        try await statusesService.send(reblog: payload, on: context)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        await context.logger.store("StatusRebloggerJob error. Status (id: '\(payload)').", error, on: context.application)
    }
}
