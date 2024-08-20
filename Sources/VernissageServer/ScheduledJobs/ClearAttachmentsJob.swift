//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Queues

/// A background task that cleans files that have not been attached to any status.
struct ClearAttachmentsJob: AsyncScheduledJob {
    let jobId = "ClearAttachmentsJob"

    func run(context: QueueContext) async throws {
        context.logger.info("ClearAttachmentsJob is running.")

        // Check if current job can perform the work.
        guard try await self.single(jobId: self.jobId, on: context) else {
            return
        }
        
        // Get all atatchments older then 24 hours not connected to any status.
        let yesterday = Date.yesterday
        let attachments = try await Attachment.query(on: context.application.db)
            .filter(\.$createdAt < yesterday)
            .filter(\.$status.$id == nil)
            .with(\.$originalFile)
            .with(\.$smallFile)
            .all()
                
        context.logger.info("ClearAttachmentsJob old attachments to delete: \(attachments.count).")
        
        let storageService = context.application.services.storageService
        for attachment in attachments {
            do {
                // Remove files from external storage provider.
                try await storageService.delete(fileName: attachment.originalFile.fileName, on: context)
                try await storageService.delete(fileName: attachment.smallFile.fileName, on: context)
                
                // Remove attachment from database.
                try await attachment.delete(on: context.application.db)
            } catch {
                context.logger.error("ClearAttachmentsJob error: \(error.localizedDescription)")
            }
        }
        
        context.logger.info("ClearAttachmentsJob all old attachments deleted.")
    }
}
