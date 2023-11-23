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

struct TrendingJob: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        context.logger.info("TrendingJob is running.")

        let trendingService = context.application.services.trendingService
        await trendingService.calculateTrendingStatuses(on: context)
        
        context.logger.info("TrendingJob finished.")
    }
}
