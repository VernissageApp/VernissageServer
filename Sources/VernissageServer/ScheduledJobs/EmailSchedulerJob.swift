//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Queues
import Vapor

/// Re-enqueues email deliveries that are waiting, ready for retry or left processing after a worker failure.
struct EmailSchedulerJob: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        context.logger.info("[EmailSchedulerJob] Job is running.")
        try await context.application.services.emailDeliveryService.dispatchPending(on: context.executionContext)
        context.logger.info("[EmailSchedulerJob] Job finished.")
    }
}
