//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Queues

/// A background task that cleans files that have not been attached to any status.
struct ClearAttachmentsJob: AsyncScheduledJob {
    let jobId = "ClearAttachmentsJob"

    func run(context: QueueContext) async throws {
        let applicationSettings = context.application.settings.cached
        if applicationSettings?.clearAttachmentsJobEnabled == false {
            context.logger.info("[ClearAttachmentsJob] Job is disabled in seetings.")
            return
        }
        
        context.logger.info("[ClearAttachmentsJob] Job is running.")
                
        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }
        
        let clearAttachmentsService = context.application.services.clearAttachmentsService
        try await clearAttachmentsService.clear(on: context.executionContext)
                
        context.logger.info("[ClearAttachmentsJob] Job finished procesing.")
    }
}
