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

/// A background task that creates archives with user's data.
struct CreateArchiveJob: AsyncScheduledJob {
    let jobId = "CreateArchiveJob"
    
    func run(context: QueueContext) async throws {
        let applicationSettings = context.application.settings.cached
        if applicationSettings?.createArchiveJobEnabled == false {
            context.logger.info("CreateArchiveJob is disabled in seetings.")
            return
        }
        
        context.logger.info("CreateArchiveJob is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }

        let archivesService = context.application.services.archivesService
        let newArchiveRequests = try await Archive.query(on: context.application.db)
            .filter(\.$status == .new)
            .all()
        
        context.logger.info("CreateArchiveJob found \(newArchiveRequests.count) archives to create.")
        
        for newArchiveRequest in newArchiveRequests {
            do {
                try await archivesService.create(for: newArchiveRequest.requireID(), on: context)
            } catch {
                newArchiveRequest.status = .error
                newArchiveRequest.endDate = Date()
                newArchiveRequest.errorMessage = error.localizedDescription
                try? await newArchiveRequest.save(on: context.application.db)
                
                await context.logger.store("CreateArchiveJob error during creating new archive.", error, on: context.application)
            }
        }
        
        context.logger.info("CreateArchiveJob finished.")
    }
}
