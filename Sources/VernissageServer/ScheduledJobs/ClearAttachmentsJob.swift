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
        
        try await self.clearAttachmentHistories(on: context)
        try await self.clearAttachments(on: context)
        
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
                let attchmentHistoryOrginalFile = try await AttachmentHistory.query(on: executionContext.db)
                    .filter(\.$originalFile.$id == attachment.$originalFile.id)
                    .first()
                
                if attchmentHistoryOrginalFile == nil {
                    // Remove files from external storage provider.
                    context.logger.info("ClearAttachmentsJob delete attachment orginal file from storage: \(attachment.originalFile.fileName).")
                    try await storageService.delete(fileName: attachment.originalFile.fileName, on: executionContext)
                }
                
                let attchmentHistorySmallFile = try await AttachmentHistory.query(on: executionContext.db)
                    .filter(\.$smallFile.$id == attachment.$smallFile.id)
                    .first()
                
                if attchmentHistorySmallFile == nil {
                    context.logger.info("ClearAttachmentsJob delete attachment small file from storage: \(attachment.smallFile.fileName).")
                    try await storageService.delete(fileName: attachment.smallFile.fileName, on: executionContext)
                }

                let attchmentHistoryOriginalHdrFile = try await AttachmentHistory.query(on: executionContext.db)
                    .filter(\.$originalHdrFile.$id == attachment.$originalHdrFile.id)
                    .first()
                
                if let orginalHdrFileName = attachment.originalHdrFile?.fileName, attchmentHistoryOriginalHdrFile == nil {
                    context.logger.info("ClearAttachmentsJob delete attachment orginal HDR file from storage: \(orginalHdrFileName).")
                    try await storageService.delete(fileName: orginalHdrFileName, on: executionContext)
                }
                
                // Remove attachment from database.
                context.logger.info("ClearAttachmentsJob delete attachment from database: \(attachment.stringId() ?? "").")
                try await context.application.db.transaction { transaction in
                    try await attachment.exif?.delete(on: transaction)
                    try await attachment.delete(on: transaction)

                    if attchmentHistoryOrginalFile == nil {
                        try await attachment.originalFile.delete(on: transaction)
                    }
                    
                    if attchmentHistorySmallFile == nil {
                        try await attachment.smallFile.delete(on: transaction)
                    }
                    
                    if attchmentHistoryOriginalHdrFile == nil {
                        try await attachment.originalHdrFile?.delete(on: transaction)
                    }
                }
            } catch {
                await context.logger.store("ClearAttachmentsJob delete attachment error.", error, on: context.application)
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
                let attchmentOrginalFile = try await Attachment.query(on: executionContext.db)
                    .filter(\.$originalFile.$id == attachmentHistory.$originalFile.id)
                    .first()
                
                // Remove files from external storage provider.
                if attchmentOrginalFile == nil {
                    context.logger.info("ClearAttachmentsJob delete attachment history orginal file from storage: \(attachmentHistory.originalFile.fileName).")
                    try await storageService.delete(fileName: attachmentHistory.originalFile.fileName, on: executionContext)
                }
                
                let attchmentSmallFile = try await Attachment.query(on: executionContext.db)
                    .filter(\.$smallFile.$id == attachmentHistory.$smallFile.id)
                    .first()
                
                if attchmentSmallFile == nil {
                    context.logger.info("ClearAttachmentsJob delete attachment history small file from storage: \(attachmentHistory.smallFile.fileName).")
                    try await storageService.delete(fileName: attachmentHistory.smallFile.fileName, on: executionContext)
                }

                let attchmentOriginalHdrFile = try await Attachment.query(on: executionContext.db)
                    .filter(\.$originalHdrFile.$id == attachmentHistory.$originalHdrFile.id)
                    .first()
                
                if let orginalHdrFileName = attachmentHistory.originalHdrFile?.fileName, attchmentOriginalHdrFile == nil {
                    context.logger.info("ClearAttachmentsJob delete attachment history orginal HDR file from storage: \(orginalHdrFileName).")
                    try await storageService.delete(fileName: orginalHdrFileName, on: executionContext)
                }
                
                // Remove attachment from database.
                context.logger.info("ClearAttachmentsJob delete attachment history from database: \(attachmentHistory.stringId() ?? "").")
                try await context.application.db.transaction { transaction in
                    try await attachmentHistory.exif?.delete(on: transaction)
                    try await attachmentHistory.delete(on: transaction)

                    if attchmentOrginalFile == nil {
                        try await attachmentHistory.originalFile.delete(on: transaction)
                    }
                    
                    if attchmentSmallFile == nil {
                        try await attachmentHistory.smallFile.delete(on: transaction)
                    }
                    
                    if attchmentOriginalHdrFile == nil {
                        try await attachmentHistory.originalHdrFile?.delete(on: transaction)
                    }
                }
            } catch {
                await context.logger.store("ClearAttachmentsJob delete attachment history error.", error, on: context.application)
            }
        }
    }
}
