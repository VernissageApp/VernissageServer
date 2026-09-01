//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension Application.Services {
    struct CollectionsServiceKey: StorageKey {
        typealias Value = CollectionsServiceType
    }

    var collectionsService: CollectionsServiceType {
        get {
            self.application.storage[CollectionsServiceKey.self] ?? CollectionsService()
        }
        nonmutating set {
            self.application.storage[CollectionsServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol CollectionsServiceType: Sendable {
    /// Synchronizes pinned statuses for a remote user using their ActivityPub `featured` collection.
    /// - Parameters:
    ///   - userId: Unique identifier of the remote user to synchronize.
    ///   - context: Execution context with database and application services.
    /// - Throws: Database or ActivityPub communication errors.
    func synchronizeFeaturedCollection(for userId: Int64, on context: ExecutionContext) async throws

    /// Sends ActivityPub `Add` activity for a pinned local status to followers' inboxes.
    /// - Parameters:
    ///   - statusId: Unique identifier of pinned status.
    ///   - context: Execution context with database and application services.
    /// - Throws: Database or ActivityPub communication errors.
    func sendAddToFeatured(for statusId: Int64, on context: ExecutionContext) async throws

    /// Sends ActivityPub `Remove` activity for an unpinned local status to followers' inboxes.
    /// - Parameters:
    ///   - statusId: Unique identifier of unpinned status.
    ///   - context: Execution context with database and application services.
    /// - Throws: Database or ActivityPub communication errors.
    func sendRemoveFromFeatured(for statusId: Int64, on context: ExecutionContext) async throws

}

final class CollectionsService: CollectionsServiceType {

    func synchronizeFeaturedCollection(for userId: Int64, on context: ExecutionContext) async throws {
        let activityPubDownloadCollectionService = context.services.activityPubDownloadCollectionService
        let activityPubDownloadStatusService = context.services.activityPubDownloadStatusService
        let statusesService = context.services.statusesService

        guard let user = try await User.query(on: context.db)
            .filter(\.$id == userId)
            .first() else {
            context.logger.warning("Featured collection synchronization skipped. User not found (id: '\(userId)').")
            return
        }

        guard user.isLocal == false else {
            return
        }

        guard let featuredUrlString = user.featured, featuredUrlString.isEmpty == false else {
            try await self.clearPinnedStatuses(for: userId, on: context.db)
            return
        }

        guard let featuredUrl = URL(string: featuredUrlString) else {
            context.logger.warning("Featured collection URL is invalid: '\(featuredUrlString)'.")
            try await self.clearPinnedStatuses(for: userId, on: context.db)
            return
        }

        let featuredCollectionData = try await activityPubDownloadCollectionService.downloadFeaturedCollection(featuredUrl: featuredUrl, on: context)
        let featuredStatusIds = featuredCollectionData.statusIds

        for featuredStatusId in featuredStatusIds {
            var status = try await statusesService.get(activityPubId: featuredStatusId, on: context.db)

            if status == nil,
               let noteDto = featuredCollectionData.statusNotes[featuredStatusId],
               noteDto.attributedTo == user.activityPubProfile {

                guard noteDto.type == "Note" else {
                    context.logger.warning("Featured collection object type '\(noteDto.type)' is not supported (status: \(featuredStatusId)).")
                    continue
                }

                // Prevent creating new statuses when status doesn't contains any image.
                guard let attachments = noteDto.attachment, !attachments.isEmpty, attachments.hasSupportedImages() else {
                    context.logger.warning("Featured collection note doesn't contain supported image attachments (status: \(featuredStatusId)).")
                    continue
                }

                // Try to create status based on data from the collection.
                status = try? await statusesService.create(basedOn: noteDto,
                                                           userId: userId,
                                                           visibility: .public,
                                                           on: context)
            }

            // When we don't have status in collection od creating failed then try to download status from remote server.
            if status == nil {
                status = try? await activityPubDownloadStatusService.download(activityPubId: featuredStatusId, on: context)
            }

            guard let status, status.$user.id == userId else {
                continue
            }

            // Mark status as pinned.
            status.pinnedAt = Date()
            try await status.save(on: context.db)
        }

        let pinnedStatuses = try await Status.query(on: context.db)
            .filter(\.$user.$id == userId)
            .filter(\.$pinnedAt != nil)
            .all()

        for pinnedStatus in pinnedStatuses where featuredStatusIds.contains(pinnedStatus.activityPubId) == false {
            pinnedStatus.pinnedAt = nil
            try await pinnedStatus.save(on: context.db)
        }
    }

    func sendAddToFeatured(for statusId: Int64, on context: ExecutionContext) async throws {
        let activityPubOutgoingCollectionService = context.services.activityPubOutgoingCollectionService
        try await activityPubOutgoingCollectionService.sendFeaturedChange(for: statusId, type: .add, on: context)
    }

    func sendRemoveFromFeatured(for statusId: Int64, on context: ExecutionContext) async throws {
        let activityPubOutgoingCollectionService = context.services.activityPubOutgoingCollectionService
        try await activityPubOutgoingCollectionService.sendFeaturedChange(for: statusId, type: .remove, on: context)
    }

    private func clearPinnedStatuses(for userId: Int64, on database: Database) async throws {
        let pinnedStatuses = try await Status.query(on: database)
            .filter(\.$user.$id == userId)
            .filter(\.$pinnedAt != nil)
            .all()

        for pinnedStatus in pinnedStatuses {
            pinnedStatus.pinnedAt = nil
            try await pinnedStatus.save(on: database)
        }
    }
}
