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

/// A background task that deletes archives with user's data.
struct DeleteArchiveJob: AsyncScheduledJob {
    let jobId = "DeleteArchiveJob"
    
    func run(context: QueueContext) async throws {
        let applicationSettings = context.application.settings.cached
        if applicationSettings?.deleteArchiveJobEnabled == false {
            context.logger.info("[DeleteArchiveJob] Job is disabled in seetings.")
            return
        }
        
        context.logger.info("[DeleteArchiveJob] Job is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let archivesService = context.application.services.archivesService
        let monthAgo = Date.monthAgo
        let oldArchiveRequests = try await Archive.query(on: context.application.db)
            .filter(\.$status == .ready)
            .filter(\.$requestDate < monthAgo)
            .all()
        
        context.logger.info("[DeleteArchiveJob] Job found \(oldArchiveRequests.count) archives to delete.")
        
        for oldArchiveRequest in oldArchiveRequests {
            do {
                try await archivesService.delete(for: oldArchiveRequest.requireID(), on: context)
            } catch {
                await context.logger.store("[DeleteArchiveJob] Error during deleting old archive.", error, on: context.application)
            }
        }
        
        context.logger.info("[DeleteArchiveJob] Job finished processing.")
    }
}
