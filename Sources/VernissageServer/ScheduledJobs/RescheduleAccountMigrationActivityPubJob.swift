//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Queues
import Vapor

/// Re-enqueues migration deliveries that are waiting, ready for retry or left processing after a worker failure.
struct RescheduleAccountMigrationActivityPubJob: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        guard context.application.settings.cached?.rescheduleActivityPubJobEnabled != false else {
            context.logger.info("[RescheduleAccountMigrationActivityPubJob] Job is disabled in settings.")
            return
        }

        context.logger.info("[RescheduleAccountMigrationActivityPubJob] Job is running.")
        try await context.application.services.accountMigrationActivityPubService.dispatchPending(on: context.executionContext)
        context.logger.info("[RescheduleAccountMigrationActivityPubJob] Job finished.")
    }
}
