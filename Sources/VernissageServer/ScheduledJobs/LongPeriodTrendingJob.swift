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

/// A background task that lists the most popular statuses, tags and users (monthly/yearly).
struct LongPeriodTrendingJob: AsyncScheduledJob {
    let jobId = "LongPeriodTrendingJob"
    
    func run(context: QueueContext) async throws {
        context.logger.info("LongPeriodTrendingJob is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let trendingService = context.application.services.trendingService
        
        // Recalculate trending statuses.
        await trendingService.calculateTrendingStatuses(period: .monthly, on: context)
        await trendingService.calculateTrendingStatuses(period: .yearly, on: context)

        // Recalculate trending users.
        await trendingService.calculateTrendingUsers(period: .monthly, on: context)
        await trendingService.calculateTrendingUsers(period: .yearly, on: context)

        // Recalculate trending hashtags.
        await trendingService.calculateTrendingHashtags(period: .monthly, on: context)
        await trendingService.calculateTrendingHashtags(period: .yearly, on: context)
        
        context.logger.info("LongPeriodTrendingJob finished.")
    }
}
