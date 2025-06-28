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

/// A background task that clears old failed logins attempts.
struct ClearFailedLoginsJob: AsyncScheduledJob {
    let jobId = "ClearFailedLoginsJob"
    
    func run(context: QueueContext) async throws {
        context.logger.info("ClearFailedLoginsJob is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let failedLoginsService = context.application.services.failedLoginsService
        try await failedLoginsService.clear(on: context.application.db)
        
        context.logger.info("ClearFailedLoginsJob finished.")
    }
}
