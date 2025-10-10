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

/// A background task that reschedules ActivityPub jobs when they didn't finished.
struct RescheduleActivityPubJob: AsyncScheduledJob {
    let jobId = "RescheduleActivityPubJob"
    
    func run(context: QueueContext) async throws {
        let applicationSettings = context.application.settings.cached
        if applicationSettings?.rescheduleActivityPubJobEnabled == false {
            context.logger.info("RescheduleActivityPubJob is disabled in seetings.")
            return
        }
        
        context.logger.info("RescheduleActivityPubJob is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let hourAgo = Date.hourAgo
        let eventsToReschedule = try await StatusActivityPubEvent.query(on: context.application.db)
            .filter(\.$result == .waiting)
            .filter(\.$createdAt < hourAgo)
            .filter(\.$attempts < 3)
            .all()
        
        context.logger.info("RescheduleActivityPubJob found \(eventsToReschedule.count) events to reschedule.")

        for eventToReschedule in eventsToReschedule {
            do {
                try await context
                    .queues(.apStatus)
                    .dispatch(ActivityPubStatusJob.self, ActivityPubStatusJobDataDto(statusActivityPubEventId: eventToReschedule.requireID()))
            } catch {
                await context.logger.store("RescheduleActivityPubJob error during reschedule ActivityPub event.", error, on: context.application)
            }
        }
        
        context.logger.info("RescheduleActivityPubJob finished.")
    }
}
