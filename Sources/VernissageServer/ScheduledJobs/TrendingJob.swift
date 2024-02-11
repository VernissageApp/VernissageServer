//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Foundation
import Queues
import Smtp
import RegexBuilder
import Redis

/// A background task that lists the most popular statuses, tags and users.
struct TrendingJob: AsyncScheduledJob {
    let jobId = "TrendingJob"
    
    func run(context: QueueContext) async throws {
        context.logger.info("TrendingJob is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let trendingService = context.application.services.trendingService
        await trendingService.calculateTrendingStatuses(on: context)
        await trendingService.calculateTrendingUsers(on: context)
        await trendingService.calculateTrendingHashtags(on: context)
        
        context.logger.info("TrendingJob finished.")
    }
}
