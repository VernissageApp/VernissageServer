//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

extension Application.Services {
    struct PurgeStatusesServiceKey: StorageKey {
        typealias Value = PurgeStatusesServiceType
    }

    var purgeStatusesService: PurgeStatusesServiceType {
        get {
            self.application.storage[PurgeStatusesServiceKey.self] ?? PurgeStatusesService()
        }
        nonmutating set {
            self.application.storage[PurgeStatusesServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol PurgeStatusesServiceType: Sendable {
    /// Removes old statuses from the system that have no interactions associated with them.
    ///
    /// - Parameter context: The execution context providing access to services, settings, and the database.
    /// - Throws: An error if the purge operation fails.
    func purge(on context: ExecutionContext) async throws
}

/// A service for deleting old statuses without any interactions.
final class PurgeStatusesService: PurgeStatusesServiceType {
    private let minSleepDelay: Duration = .milliseconds(500)
    private let maxSleepDelay: Duration = .seconds(3)

    final private class ReblogStatus: ModelAlias {
        static let name = "reblogStatus"
        let model = Status()
    }

    final private class CommentStatus: ModelAlias {
        static let name = "commentStatus"
        let model = Status()
    }
    
    func purge(on context: ExecutionContext) async throws {
        let applicationSettings = context.settings.cached
        let statusPurgeAfterDays = applicationSettings?.statusPurgeAfterDays ?? 180
        let purgeStartTime = Date()
        
        // We don't want to delete statuses younger than 30 days by mistake.
        let purgeDays = statusPurgeAfterDays > 30 ? statusPurgeAfterDays : 30
        let limit = 250
                
        context.logger.info("[PurgeStatusesJob] Purging statuses older than: \(purgeDays) days (limit: \(limit) statuses).")
        let statusesToPurge = try await self.getStatusesToPurge(purgeDays: statusPurgeAfterDays, limit: limit, on: context)
        context.logger.info("[PurgeStatusesJob] Satuses do delete: \(statusesToPurge.count).")

        // Backoff sleep timers.
        var adaptiveDelay = minSleepDelay
        var successStreak = 0

        let statusesService = context.services.statusesService
        for (index, status) in statusesToPurge.enumerated() {
            do {
                // We will delete statuses only for 10 minutes (after that time next job will be scheduled).
                if purgeStartTime < Date.tenMinutesAgo {
                    context.logger.info("[PurgeStatusesJob] Stopping purging statuses after 10 minutes of working.")
                    break
                }
                
                context.logger.info("[PurgeStatusesJob] Deleting status (\(index + 1)/\(statusesToPurge.count): '\(status.stringId() ?? "")'.")
                
                let deleteStart = ContinuousClock.now
                try await statusesService.delete(id: status.requireID(), on: context.db)
                let deleteEnd = ContinuousClock.now
                
                context.logger.info("[PurgeStatusesJob] Status: '\(status.stringId() ?? "")' deleted in \(deleteEnd - deleteStart).")
                
                // We have to wait some time to reduce database stress.
                context.logger.info("[PurgeStatusesJob] Waiting: '\(adaptiveDelay)' to process next status.")
                try await Task.sleep(for: adaptiveDelay)
                
                // When we had few successess we can reduce sleep delay.
                successStreak += 1
                if successStreak >= 3 {
                    adaptiveDelay = max(adaptiveDelay - .milliseconds(50), minSleepDelay)
                    successStreak = 0
                }
            } catch EntityNotFoundError.statusNotFound {
                context.logger.error("[PurgeStatusesJob] Status: \(status.stringId() ?? "") already deleted.")

                // After an error we will sleep to reduce system stress.
                context.logger.info("[PurgeStatusesJob] Waiting: '\(adaptiveDelay)' to process next status.")
                try? await Task.sleep(for: adaptiveDelay)
            } catch {
                context.logger.error("[PurgeStatusesJob] Error during deleting status: \(status.stringId() ?? ""), error: \(error).")
                
                // When we had an error we have to increase sleep delay.
                adaptiveDelay = min(adaptiveDelay * 2, maxSleepDelay)
                successStreak = 0

                // After an error we will sleep to reduce system stress.
                context.logger.info("[PurgeStatusesJob] Waiting: '\(adaptiveDelay)' to process next status.")
                try? await Task.sleep(for: adaptiveDelay)
            }
        }
    }
    
    private func getStatusesToPurge(purgeDays: Int, limit: Int, on context: ExecutionContext) async throws -> [Status] {
        let purgeDaysDate = Date.ago(days: purgeDays)

        let queryJoins = Status.query(on: context.db)
            .join(ReblogStatus.self, on: \Status.$id == \ReblogStatus.$reblog.$id, method: .left)
            .join(CommentStatus.self, on: \Status.$id == \CommentStatus.$replyToStatus.$id && \CommentStatus.$isLocal == true, method: .left)
            .join(StatusFavourite.self, on: \Status.$id == \StatusFavourite.$status.$id, method: .left)
            .join(FeaturedStatus.self, on: \Status.$id == \FeaturedStatus.$status.$id, method: .left)
            .join(StatusBookmark.self, on: \Status.$id == \StatusBookmark.$status.$id, method: .left)
        
        let queryFilter = queryJoins
            .filter(Status.self, \.$createdAt < purgeDaysDate)
            .filter(Status.self, \.$isLocal == false)
            .filter(ReblogStatus.self, \.$createdAt == nil)
            .filter(CommentStatus.self, \.$createdAt == nil)
            .filter(StatusFavourite.self, \.$createdAt == nil)
            .filter(FeaturedStatus.self, \.$createdAt == nil)
            .filter(StatusBookmark.self, \.$createdAt == nil)
        
        let querySort = queryFilter
            .sort(Status.self, \.$createdAt)
            .limit(limit)
                
        let values = try await querySort.all()
        return values
    }
}

