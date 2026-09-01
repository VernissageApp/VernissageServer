//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Queues
import Vapor

/// Re-enqueues migration deliveries that are waiting, ready for retry or left processing after a worker failure.
struct RescheduleAccountMigrationActivityPubJob: AsyncScheduledJob {
    private let jobId = "RescheduleAccountMigrationActivityPubJob"

    func run(context: QueueContext) async throws {
        guard context.application.settings.cached?.rescheduleActivityPubJobEnabled != false else {
            context.logger.info("[RescheduleAccountMigrationActivityPubJob] Job is disabled in settings.")
            return
        }

        context.logger.info("[RescheduleAccountMigrationActivityPubJob] Job is running.")

        guard try await self.single(jobId: self.jobId, lockFor: 14 * 60, on: context) else {
            return
        }

        try await context.application.services.accountMigrationActivityPubService.dispatchPending(on: context.executionContext)
        context.logger.info("[RescheduleAccountMigrationActivityPubJob] Job finished.")
    }
}
