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
            context.logger.info("[RescheduleActivityPubJob] Job is disabled in seetings.")
            return
        }
        
        context.logger.info("[RescheduleActivityPubJob] Job is running.")

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
        
        context.logger.info("[RescheduleActivityPubJob] Job found \(eventsToReschedule.count) events to reschedule.")

        for eventToReschedule in eventsToReschedule {
            do {
                switch eventToReschedule.type {
                    case .create:
                        try await retryStatusCreate(eventToReschedule: eventToReschedule, on: context)
                    case .update:
                        try await retryStatusUpdate(eventToReschedule: eventToReschedule, on: context)
                    case .like:
                        try await retryStatusLike(eventToReschedule: eventToReschedule, on: context)
                    case .unlike:
                        try await retryStatusUnlike(eventToReschedule: eventToReschedule, on: context)
                    case .announce:
                        try await retryStatusAnnounce(eventToReschedule: eventToReschedule, on: context)
                    case .unannounce:
                        try await retryStatusUnannounce(eventToReschedule: eventToReschedule, on: context)
                }

            } catch {
                await context.logger.store("[RescheduleActivityPubJob] Error during reschedule ActivityPub event.", error, on: context.application)
            }
        }
        
        context.logger.info("[RescheduleActivityPubJob] Job finished processing.")
    }
    
    private func retryStatusCreate(eventToReschedule: StatusActivityPubEvent, on context: QueueContext) async throws {
        try await context
            .queues(.apStatus)
            .dispatch(ActivityPubStatusJob.self, ActivityPubStatusJobDataDto(statusActivityPubEventId: eventToReschedule.requireID()))
    }
    
    private func retryStatusUpdate(eventToReschedule: StatusActivityPubEvent, on context: QueueContext) async throws {
        try await context
            .queues(.apStatus)
            .dispatch(ActivityPubStatusJob.self, ActivityPubStatusJobDataDto(statusActivityPubEventId: eventToReschedule.requireID()))
    }
    
    private func retryStatusLike(eventToReschedule: StatusActivityPubEvent, on context: QueueContext) async throws {
        let statusFavourite = try await StatusFavourite.query(on: context.application.db)
            .filter(\.$user.$id == eventToReschedule.$user.id)
            .filter(\.$status.$id == eventToReschedule.$status.id)
            .first()
        
        guard let statusFavourite else {
            let errorMessage = "Status favourite event: '\(eventToReschedule.stringId() ?? "")' cannot be send to shared inbox. Cannot find user status favourite."
            
            // Mark event as finished with error.
            try await eventToReschedule.error(errorMessage, on: context.executionContext)

            context.logger.warning("\(errorMessage)")
            return
        }
        
        try await context
            .queues(.apStatus)
            .dispatch(ActivityPubStatusJob.self, ActivityPubStatusJobDataDto(statusActivityPubEventId: eventToReschedule.requireID(),
                                                                             statusFavouriteId: statusFavourite.stringId()))
    }
    
    private func retryStatusUnlike(eventToReschedule: StatusActivityPubEvent, on context: QueueContext) async throws {
        try await self.retryStatusEventBasedOnEventContext(eventToReschedule: eventToReschedule, on: context)
    }
    
    private func retryStatusAnnounce(eventToReschedule: StatusActivityPubEvent, on context: QueueContext) async throws {
        try await self.retryStatusEventBasedOnEventContext(eventToReschedule: eventToReschedule, on: context)
    }
    
    private func retryStatusUnannounce(eventToReschedule: StatusActivityPubEvent, on context: QueueContext) async throws {
        try await self.retryStatusEventBasedOnEventContext(eventToReschedule: eventToReschedule, on: context)
    }
    
    private func retryStatusEventBasedOnEventContext(eventToReschedule: StatusActivityPubEvent, on context: QueueContext) async throws {
        guard let eventContextString = eventToReschedule.eventContext else {
            let errorMessage = "Status \(eventToReschedule.type) event: '\(eventToReschedule.stringId() ?? "")' cannot be send to shared inbox. Cannot find status event context."
            
            // Mark event as finished with error.
            try await eventToReschedule.error(errorMessage, on: context.executionContext)

            context.logger.warning("\(errorMessage)")
            return
        }
        
        guard let activityPubStatusJobDataDto = try? ActivityPubStatusJobDataDto(from: eventContextString) else {
            let errorMessage = "Status \(eventToReschedule.type) event: '\(eventToReschedule.stringId() ?? "")' cannot be send to shared inbox. Cannot decode event context."
            
            // Mark event as finished with error.
            try await eventToReschedule.error(errorMessage, on: context.executionContext)

            context.logger.warning("\(errorMessage)")
            return
        }
        
        try await context
            .queues(.apStatus)
            .dispatch(ActivityPubStatusJob.self, activityPubStatusJobDataDto)
    }
}
