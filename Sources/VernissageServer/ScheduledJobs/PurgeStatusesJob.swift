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
        context.logger.info("PurgeStatusesJob is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let purgeStatusesService = context.application.services.purgeStatusesService
        try await purgeStatusesService.purge(on: context.executionContext)
        
        context.logger.info("PurgeStatusesJob finished.")
    }
}
