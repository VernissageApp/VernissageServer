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

/// A background task that lists the most popular statuses, tags and users (daily).
struct ShortPeriodTrendingJob: AsyncScheduledJob {
    let jobId = "ShortPeriodTrendingJob"
    
    func run(context: QueueContext) async throws {
        let applicationSettings = context.application.settings.cached
        if applicationSettings?.shortPeriodTrendingJobEnabled == false {
            context.logger.info("[ShortPeriodTrendingJob] Job is disabled in seetings.")
            return
        }
        
        context.logger.info("[ShortPeriodTrendingJob] Job is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let trendingService = context.application.services.trendingService

        await trendingService.calculateTrendingStatuses(period: .daily, on: context)
        await trendingService.calculateTrendingUsers(period: .daily, on: context)
        await trendingService.calculateTrendingHashtags(period: .daily, on: context)
        
        context.logger.info("[ShortPeriodTrendingJob] Job finished processing.")
    }
}
