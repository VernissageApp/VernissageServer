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
    func purge(on context: ExecutionContext) async throws
}

/// A service for deleting old statuses without any interactions.
final class PurgeStatusesService: PurgeStatusesServiceType {
    final private class ReblogStatus: ModelAlias {
        static let name = "reblogStatus"
        let model = Status()
    }
    final private class CommentStatus: ModelAlias {
        static let name = "commentStatus"
        let model = Status()
    }
    
    func purge(on context: ExecutionContext) async throws {
        let appplicationSettings = context.settings.cached
        let statusPurgeAfterDays = appplicationSettings?.statusPurgeAfterDays ?? 180
        
        // We don't want to delete statuses younger than 30 days by mistake.
        let purgeDays = statusPurgeAfterDays > 30 ? statusPurgeAfterDays : 30
        let limit = 250
        
        context.logger.info("[PurgeStatusesJob] Purging statuses older than: \(purgeDays) days (limit: \(limit) statuses).")
        let statusesToPurge = try await self.getStatusesToPurge(purgeDays: statusPurgeAfterDays, limit: limit, on: context)
        context.logger.info("[PurgeStatusesJob] Satuses do delete: \(statusesToPurge.count)")

        let statusesService = context.services.statusesService
        for (index, status) in statusesToPurge.enumerated() {
            do {
                context.logger.info("[PurgeStatusesJob] Deleting status (\(index + 1)/\(statusesToPurge.count): '\(status.stringId() ?? "")', activityPubId: '\(status.activityPubId)'")
                try await statusesService.delete(id: status.requireID(), on: context.db)
                context.logger.info("[PurgeStatusesJob] Status: '\(status.stringId() ?? "")' deleted.")
            } catch {
                context.logger.error("[PurgeStatusesJob] Error during deleting status: \(status.stringId() ?? ""), error: \(error)")
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
        
        let gueryFilter = queryJoins
            .filter(Status.self, \.$createdAt < purgeDaysDate)
            .filter(Status.self, \.$isLocal == false)
            .filter(ReblogStatus.self, \.$createdAt == nil)
            .filter(CommentStatus.self, \.$createdAt == nil)
            .filter(StatusFavourite.self, \.$createdAt == nil)
            .filter(FeaturedStatus.self, \.$createdAt == nil)
            .filter(StatusBookmark.self, \.$createdAt == nil)
        
        let values = try await gueryFilter
            .sort(Status.self, \.$createdAt)
            .limit(limit)
            .all()
        
        return values
    }
}
