//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Queues

/// A background task that cleans remote users from database that failed to delete.
struct ClearDeletedUsersJob: AsyncScheduledJob {
    let jobId = "ClearDeletedUsersJob"

    func run(context: QueueContext) async throws {
        let applicationSettings = context.application.settings.cached
        if applicationSettings?.clearDeletedUsersJobEnabled == false {
            context.logger.info("[ClearDeletedUsersJob] Job is disabled in seetings.")
            return
        }
        
        context.logger.info("[ClearDeletedUsersJob] Job is running.")
                
        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }
        
        let clearDeletedUsersService = context.application.services.clearDeletedUsersService
        try await clearDeletedUsersService.clear(on: context.executionContext)
                
        context.logger.info("[ClearDeletedUsersJob] Job finished procesing.")
    }
}
