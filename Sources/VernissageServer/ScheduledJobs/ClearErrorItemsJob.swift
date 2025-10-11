//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Foundation
import Queues
import Smtp
import RegexBuilder
import Redis

/// A background task that clears error items table.
struct ClearErrorItemsJob: AsyncScheduledJob {
    let jobId = "ClearErrorItemsJob"
    
    func run(context: QueueContext) async throws {
        let applicationSettings = context.application.settings.cached
        if applicationSettings?.clearErrorItemsJobEnabled == false {
            context.logger.info("[ClearErrorItemsJob] Job is disabled in seetings.")
            return
        }
        
        context.logger.info("[ClearErrorItemsJob] Job is running.")
        
        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let errorItemsService = context.application.services.errorItemsService
        try await errorItemsService.clear(on: context.application.db)
        
        context.logger.info("[ClearErrorItemsJob] Job finished processing.")
    }
}
