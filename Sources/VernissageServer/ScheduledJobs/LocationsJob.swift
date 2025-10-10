//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Foundation
import Queues

/// A background task that fills the locations table.
struct LocationsJob: AsyncScheduledJob {
    let jobId = "LocationsJob"
    
    func run(context: QueueContext) async throws {
        let applicationSettings = context.application.settings.cached
        if applicationSettings?.locationsJobEnabled == false {
            context.logger.info("LocationsJob is disabled in seetings.")
            return
        }
        
        context.logger.info("LocationsJob is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let locationsService = context.application.services.locationsService
        try await locationsService.fill(on: context.executionContext)

        context.logger.info("LocationsJob finished.")
    }
}
