//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct ClearAttachmentsServiceKey: StorageKey {
        typealias Value = ClearAttachmentsServiceType
    }

    var clearAttachmentsService: ClearAttachmentsServiceType {
        get {
            self.application.storage[ClearAttachmentsServiceKey.self] ?? ClearAttachmentsService()
        }
        nonmutating set {
            self.application.storage[ClearAttachmentsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol ClearAttachmentsServiceType: Sendable {
    /// Removes old attachments which are not connected to any status.
    ///
    /// - Parameter context: The execution context providing access to services, settings, and the database.
    /// - Throws: An error if the purge operation fails.
    func clear(on context: ExecutionContext) async throws
}

/// A service for deleting attachments not connected with any status.
final class ClearAttachmentsService: ClearAttachmentsServiceType {
    private let minSleepDelay: Duration = .milliseconds(500)
    private let maxSleepDelay: Duration = .seconds(3)
    
    func clear(on context: ExecutionContext) async throws {
        try await self.clearAttachmentHistories(on: context)
        try await self.clearAttachments(on: context)
    }
    
    private func clearAttachments(on context: ExecutionContext) async throws {
        let clearStartTime = Date()
        
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
                
        context.logger.info("[ClearAttachmentsJob] Old attachments to delete: \(attachments.count).")
        
        // Backoff sleep timers.
        var adaptiveDelay = minSleepDelay
        var successStreak = 0
        
        let storageService = context.application.services.storageService
        for (index, attachment) in attachments.enumerated() {
            do {
                // We will delete attachments only for 15 minutes (after that time next job will be scheduled).
                if clearStartTime < Date.fifteenMinutesAgo {
                    context.logger.info("[ClearAttachmentsJob] Stopping deleting attachments after 15 minutes of working.")
                    break
                }
                
                context.logger.info("[ClearAttachmentsJob] Deleting attachment (\(index + 1)/\(attachments.count): '\(attachment.stringId() ?? "")'.")
                
                let attchmentHistoryOrginalFile = try await AttachmentHistory.query(on: context.db)
                    .filter(\.$originalFile.$id == attachment.$originalFile.id)
                    .first()
                
                if attchmentHistoryOrginalFile == nil {
                    // Remove files from external storage provider.
                    context.logger.info("[ClearAttachmentsJob] Delete attachment orginal file from storage: \(attachment.originalFile.fileName).")
                    try await storageService.delete(fileName: attachment.originalFile.fileName, on: context)
                }
                
                let attchmentHistorySmallFile = try await AttachmentHistory.query(on: context.db)
                    .filter(\.$smallFile.$id == attachment.$smallFile.id)
                    .first()
                
                if attchmentHistorySmallFile == nil {
                    context.logger.info("[ClearAttachmentsJob] Delete attachment small file from storage: \(attachment.smallFile.fileName).")
                    try await storageService.delete(fileName: attachment.smallFile.fileName, on: context)
                }

                let attchmentHistoryOriginalHdrFile = try await AttachmentHistory.query(on: context.db)
                    .filter(\.$originalHdrFile.$id == attachment.$originalHdrFile.id)
                    .first()
                
                if let orginalHdrFileName = attachment.originalHdrFile?.fileName, attchmentHistoryOriginalHdrFile == nil {
                    context.logger.info("[ClearAttachmentsJob] Delete attachment orginal HDR file from storage: \(orginalHdrFileName).")
                    try await storageService.delete(fileName: orginalHdrFileName, on: context)
                }
                
                // Remove attachment from database.
                context.logger.info("[ClearAttachmentsJob] Delete attachment from database: \(attachment.stringId() ?? "").")
                let deleteStart = ContinuousClock.now

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
                
                let deleteEnd = ContinuousClock.now
                context.logger.info("[ClearAttachmentsJob] Attachment: '\(attachment.stringId() ?? "")' deleted in \(deleteEnd - deleteStart).")
                
                // We have to wait some time to reduce database stress.
                context.logger.info("[ClearAttachmentsJob] Waiting: '\(adaptiveDelay)' to process next attachment.")
                try await Task.sleep(for: adaptiveDelay)

                // When we had few successess we can reduce sleep delay.
                successStreak += 1
                if successStreak >= 3 {
                    adaptiveDelay = max(adaptiveDelay - .milliseconds(50), minSleepDelay)
                    successStreak = 0
                }
                
            } catch {
                await context.logger.store("[ClearAttachmentsJob] Delete attachment error.", error, on: context.application)
                
                // When we had an error we have to increase sleep delay.
                adaptiveDelay = min(adaptiveDelay * 2, maxSleepDelay)
                successStreak = 0

                // After an error we will sleep to reduce system stress.
                context.logger.info("[ClearAttachmentsJob] Waiting: '\(adaptiveDelay)' to process next attachment.")
                try? await Task.sleep(for: adaptiveDelay)
            }
        }
    }
    
    private func clearAttachmentHistories(on context: ExecutionContext) async throws {
        let clearStartTime = Date()

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
                
        context.logger.info("[ClearAttachmentsJob] Old attachment histories to delete: \(attachmentHistories.count).")
        
        // Backoff sleep timers.
        var adaptiveDelay = minSleepDelay
        var successStreak = 0
        
        let storageService = context.application.services.storageService
        for attachmentHistory in attachmentHistories {
            do {
                // We will delete attachments only for 15 minutes (after that time next job will be scheduled).
                if clearStartTime < Date.fifteenMinutesAgo {
                    context.logger.info("[ClearAttachmentsJob] Stopping deleting attachment histories after 15 minutes of working.")
                    break
                }
                
                let attchmentOrginalFile = try await Attachment.query(on: context.db)
                    .filter(\.$originalFile.$id == attachmentHistory.$originalFile.id)
                    .first()
                
                // Remove files from external storage provider.
                if attchmentOrginalFile == nil {
                    context.logger.info("[ClearAttachmentsJob] Delete attachment history orginal file from storage: \(attachmentHistory.originalFile.fileName).")
                    try await storageService.delete(fileName: attachmentHistory.originalFile.fileName, on: context)
                }
                
                let attchmentSmallFile = try await Attachment.query(on: context.db)
                    .filter(\.$smallFile.$id == attachmentHistory.$smallFile.id)
                    .first()
                
                if attchmentSmallFile == nil {
                    context.logger.info("[ClearAttachmentsJob] Delete attachment history small file from storage: \(attachmentHistory.smallFile.fileName).")
                    try await storageService.delete(fileName: attachmentHistory.smallFile.fileName, on: context)
                }

                let attchmentOriginalHdrFile = try await Attachment.query(on: context.db)
                    .filter(\.$originalHdrFile.$id == attachmentHistory.$originalHdrFile.id)
                    .first()
                
                if let orginalHdrFileName = attachmentHistory.originalHdrFile?.fileName, attchmentOriginalHdrFile == nil {
                    context.logger.info("[ClearAttachmentsJob] Delete attachment history orginal HDR file from storage: \(orginalHdrFileName).")
                    try await storageService.delete(fileName: orginalHdrFileName, on: context)
                }
                
                // Remove attachment from database.
                context.logger.info("[ClearAttachmentsJob] Delete attachment history from database: \(attachmentHistory.stringId() ?? "").")
                let deleteStart = ContinuousClock.now

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
                
                let deleteEnd = ContinuousClock.now
                context.logger.info("[ClearAttachmentsJob] Attachment history: '\(attachmentHistory.stringId() ?? "")' deleted in \(deleteEnd - deleteStart).")
                
                // We have to wait some time to reduce database stress.
                if adaptiveDelay > .zero {
                    context.logger.info("[ClearAttachmentsJob] Waiting: '\(adaptiveDelay)' to process next attachment.")
                    try await Task.sleep(for: adaptiveDelay)
                }

                // When we had few successess we can reduce sleep delay.
                successStreak += 1
                if successStreak >= 3 {
                    adaptiveDelay = max(adaptiveDelay - .milliseconds(50), minSleepDelay)
                    successStreak = 0
                }
            } catch {
                await context.logger.store("[ClearAttachmentsJob] Delete attachment history error.", error, on: context.application)
                
                // When we had an error we have to increase sleep delay.
                adaptiveDelay = min(adaptiveDelay * 2, maxSleepDelay)
                successStreak = 0

                // After an error we will sleep to reduce system stress.
                context.logger.info("[ClearAttachmentsJob] Waiting: '\(adaptiveDelay)' to process next attachment.")
                try? await Task.sleep(for: adaptiveDelay)
            }
        }
    }
}
