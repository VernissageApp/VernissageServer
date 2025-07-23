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
        
        try await self.clearAttachments(on: context)
        try await self.clearAttachmentHistories(on: context)
        
        context.logger.info("ClearAttachmentsJob all old attachments deleted.")
    }
    
    private func clearAttachments(on context: QueueContext) async throws {
        // Get all atatchments older then 24 hours not connected to any status.
        let yesterday = Date.yesterday
        let attachments = try await Attachment.query(on: context.application.db)
            .filter(\.$createdAt < yesterday)
            .filter(\.$status.$id == nil)
            .with(\.$originalFile)
            .with(\.$smallFile)
            .with(\.$originalHdrFile)
            .with(\.$exif)
            .all()
                
        context.logger.info("ClearAttachmentsJob old attachments to delete: \(attachments.count).")
        
        let storageService = context.application.services.storageService
        let executionContext = context.executionContext

        for attachment in attachments {
            do {
                // Remove files from external storage provider.
                context.logger.info("ClearAttachmentsJob delete orginal file from storage: \(attachment.originalFile.fileName).")
                try await storageService.delete(fileName: attachment.originalFile.fileName, on: executionContext)
                
                context.logger.info("ClearAttachmentsJob delete small file from storage: \(attachment.smallFile.fileName).")
                try await storageService.delete(fileName: attachment.smallFile.fileName, on: executionContext)

                if let orginalHdrFileName = attachment.originalHdrFile?.fileName {
                    context.logger.info("ClearAttachmentsJob delete orginal HDR file from storage: \(orginalHdrFileName).")
                    try await storageService.delete(fileName: orginalHdrFileName, on: executionContext)
                }
                
                // Remove attachment from database.
                context.logger.info("ClearAttachmentsJob delete from database: \(attachment.stringId() ?? "").")
                try await context.application.db.transaction { transaction in
                    try await attachment.exif?.delete(on: transaction)
                    try await attachment.delete(on: transaction)

                    try await attachment.originalFile.delete(on: transaction)
                    try await attachment.smallFile.delete(on: transaction)
                    try await attachment.originalHdrFile?.delete(on: transaction)
                }
            } catch {
                await context.logger.store("ClearAttachmentsJob delete error.", error, on: context.application)
            }
        }
    }
    
    private func clearAttachmentHistories(on context: QueueContext) async throws {
        // Get all atatchments older then 24 hours not connected to any status.
        let yesterday = Date.yesterday
        let attachmentHistories = try await AttachmentHistory.query(on: context.application.db)
            .filter(\.$createdAt < yesterday)
            .filter(\.$statusHistory.$id == nil)
            .with(\.$originalFile)
            .with(\.$smallFile)
            .with(\.$originalHdrFile)
            .with(\.$exif)
            .all()
                
        context.logger.info("ClearAttachmentsJob old attachment histories to delete: \(attachmentHistories.count).")
        
        let storageService = context.application.services.storageService
        let executionContext = context.executionContext

        for attachmentHistory in attachmentHistories {
            do {
                // Remove files from external storage provider.
                context.logger.info("ClearAttachmentsJob delete orginal file from storage: \(attachmentHistory.originalFile.fileName).")
                try await storageService.delete(fileName: attachmentHistory.originalFile.fileName, on: executionContext)
                
                context.logger.info("ClearAttachmentsJob delete small file from storage: \(attachmentHistory.smallFile.fileName).")
                try await storageService.delete(fileName: attachmentHistory.smallFile.fileName, on: executionContext)

                if let orginalHdrFileName = attachmentHistory.originalHdrFile?.fileName {
                    context.logger.info("ClearAttachmentsJob delete orginal HDR file from storage: \(orginalHdrFileName).")
                    try await storageService.delete(fileName: orginalHdrFileName, on: executionContext)
                }
                
                // Remove attachment from database.
                context.logger.info("ClearAttachmentsJob delete from database: \(attachmentHistory.stringId() ?? "").")
                try await context.application.db.transaction { transaction in
                    try await attachmentHistory.exif?.delete(on: transaction)
                    try await attachmentHistory.delete(on: transaction)

                    try await attachmentHistory.originalFile.delete(on: transaction)
                    try await attachmentHistory.smallFile.delete(on: transaction)
                    try await attachmentHistory.originalHdrFile?.delete(on: transaction)
                }
            } catch {
                await context.logger.store("ClearAttachmentsJob delete error.", error, on: context.application)
            }
        }
    }
}
