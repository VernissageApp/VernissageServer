//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Foundation
import Queues
import Smtp
import RegexBuilder
import Redis

/// A background task that deletes old statuses from the system.
struct PurgeStatusesJob: AsyncScheduledJob {
    let jobId = "PurgeStatusesJob"
    
    func run(context: QueueContext) async throws {
        let applicationSettings = context.application.settings.cached
        if applicationSettings?.purgeStatusesJobEnabled == false {
            context.logger.info("[PurgeStatusesJob] Job is disabled in seetings.")
            return
        }
        
        context.logger.info("[PurgeStatusesJob] Job is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let purgeStatusesService = context.application.services.purgeStatusesService
        try await purgeStatusesService.purge(on: context.executionContext)
        
        context.logger.info("[PurgeStatusesJob] Job finished processing.")
    }
}
