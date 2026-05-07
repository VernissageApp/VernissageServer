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

    /// Processes inbound ActivityPub `Add` activity for collections and triggers refresh when needed.
    /// - Parameters:
    ///   - activityPubRequest: Incoming ActivityPub request payload.
    ///   - context: Execution context with database and application services.
    /// - Throws: Database or ActivityPub processing errors.
    func processAdd(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws

    /// Processes inbound ActivityPub `Remove` activity for collections and triggers refresh when needed.
    /// - Parameters:
    ///   - activityPubRequest: Incoming ActivityPub request payload.
    ///   - context: Execution context with database and application services.
    /// - Throws: Database or ActivityPub processing errors.
    func processRemove(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws
}

final class CollectionsService: CollectionsServiceType {
    private struct FeaturedCollectionData {
        let statusIds: Set<String>
        let statusNotes: [String: NoteDto]
    }

    func synchronizeFeaturedCollection(for userId: Int64, on context: ExecutionContext) async throws {
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

        let usersService = context.services.usersService
        guard let defaultSystemUser = try await usersService.getDefaultSystemUser(on: context.db) else {
            throw ActivityPubError.missingInstanceAdminAccount
        }

        guard let privateKey = defaultSystemUser.privateKey else {
            throw ActivityPubError.missingInstanceAdminPrivateKey
        }

        let activityPubClient = ActivityPubClient(privatePemKey: privateKey,
                                                  userAgent: Constants.userAgent,
                                                  host: featuredUrl.host)

        let featuredCollectionData = try await self.downloadFeaturedCollectionData(featuredUrl: featuredUrl,
                                                                                   activityPubClient: activityPubClient,
                                                                                   activityPubProfile: defaultSystemUser.activityPubProfile,
                                                                                   logger: context.logger)

        let featuredStatusIds = featuredCollectionData.statusIds
        let statusesService = context.services.statusesService
        let activityPubService = context.services.activityPubService

        for featuredStatusId in featuredStatusIds {
            var status = try await statusesService.get(activityPubId: featuredStatusId, on: context.db)

            if status == nil,
               let noteDto = featuredCollectionData.statusNotes[featuredStatusId],
               noteDto.attributedTo == user.activityPubProfile {
                
                // Prevent creating new statuses when status doesn't contains any image.
                guard let attachments = noteDto.attachment, !attachments.isEmpty, attachments.hasSupportedImages() else {
                    context.logger.warning("Featured collection note doesn't contain supported image attachments (status: \(featuredStatusId)).")
                    continue
                }

                // Try to create status based on data from the collection.
                status = try? await statusesService.create(basedOn: noteDto, userId: userId, on: context)
            }

            // When we don't have status in collection od creating failed then try to download status from remote server.
            if status == nil {
                status = try? await activityPubService.downloadStatus(activityPubId: featuredStatusId, on: context)
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
        try await self.sendFeaturedChange(for: statusId, type: .add, on: context)
    }

    func sendRemoveFromFeatured(for statusId: Int64, on context: ExecutionContext) async throws {
        try await self.sendFeaturedChange(for: statusId, type: .remove, on: context)
    }

    func processAdd(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        try await self.refreshRemoteUser(activityPubRequest: activityPubRequest, action: "Add", on: context)
    }

    func processRemove(activityPubRequest: ActivityPubRequestDto, on context: ExecutionContext) async throws {
        try await self.refreshRemoteUser(activityPubRequest: activityPubRequest, action: "Remove", on: context)
    }

    private func sendFeaturedChange(for statusId: Int64, type: ActivityTypeDto, on context: ExecutionContext) async throws {
        let statusesService = context.services.statusesService
        let followsService = context.services.followsService
        let snowflakeService = context.services.snowflakeService

        guard let status = try await statusesService.get(id: statusId, on: context.db) else {
            context.logger.warning("Cannot send '\(type.rawValue)' for featured collection. Status not found (id: \(statusId)).")
            return
        }

        guard status.user.isLocal else {
            context.logger.info("Skipping '\(type.rawValue)' for non-local status: '\(status.stringId() ?? "")'.")
            return
        }

        guard let privateKey = status.user.privateKey else {
            context.logger.warning("Cannot send '\(type.rawValue)' for featured collection. Missing private key for user '\(status.user.userName)'.")
            return
        }

        let followersInboxes = try await followsService.getFollowersOfSharedInboxes(followersOf: status.$user.id, on: context)
        let targetCollection = status.user.featured ?? "\(status.user.activityPubProfile)/featured"

        for inbox in followersInboxes {
            guard let inboxUrl = URL(string: inbox) else {
                context.logger.warning("Skipping '\(type.rawValue)' for featured collection. Invalid inbox URL '\(inbox)'.")
                continue
            }

            let activityPubClient = ActivityPubClient(privatePemKey: privateKey,
                                                      userAgent: Constants.userAgent,
                                                      host: inboxUrl.host)
            let requestId = snowflakeService.generate()

            do {
                switch type {
                case .add:
                    try await activityPubClient.addToFeatured(objectId: status.activityPubId,
                                                              actorId: status.user.activityPubProfile,
                                                              targetId: targetCollection,
                                                              on: inboxUrl,
                                                              withId: requestId)
                case .remove:
                    try await activityPubClient.removeFromFeatured(objectId: status.activityPubId,
                                                                   actorId: status.user.activityPubProfile,
                                                                   targetId: targetCollection,
                                                                   on: inboxUrl,
                                                                   withId: requestId)
                default:
                    break
                }
            } catch {
                context.logger.warning("Sending '\(type.rawValue)' to inbox failed (inbox: \(inboxUrl.absoluteString), status: \(status.activityPubId)). Error: \(error).")
            }
        }
    }

    private func refreshRemoteUser(activityPubRequest: ActivityPubRequestDto, action: String, on context: ExecutionContext) async throws {
        guard let actorId = activityPubRequest.activity.actor.actorIds().first else {
            context.logger.warning("Cannot process '\(action)' for featured collection. Missing actor id.")
            return
        }

        let targetIds = activityPubRequest.activity.target?.actorIds() ?? []
        guard targetIds.isEmpty == false else {
            context.logger.info("Skipping '\(action)' activity without target collection.")
            return
        }

        let usersService = context.services.usersService
        guard let userFromDatabase = try await usersService.get(activityPubProfile: actorId, on: context.db) else {
            context.logger.info("Skipping '\(action)' activity for unknown actor: '\(actorId)'.")
            return
        }

        if let featuredCollection = userFromDatabase.featured?.nilIfEmpty {
            guard targetIds.contains(featuredCollection) else {
                context.logger.info("Skipping '\(action)' activity for non-featured target.")
                return
            }

            try await self.synchronizeFeaturedCollection(for: userFromDatabase.requireID(), on: context)
            return
        }

        let searchService = context.services.searchService
        let refreshedUser = try await searchService.refreshRemoteUser(activityPubProfile: actorId, on: context) ?? userFromDatabase

        guard let featuredCollection = refreshedUser.featured?.nilIfEmpty else {
            context.logger.info("Skipping '\(action)' activity for actor without featured collection: '\(actorId)'.")
            return
        }

        guard targetIds.contains(featuredCollection) else {
            context.logger.info("Skipping '\(action)' activity for non-featured target.")
            return
        }

        try await self.synchronizeFeaturedCollection(for: refreshedUser.requireID(), on: context)
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

    private func downloadFeaturedCollectionData(featuredUrl: URL,
                                                activityPubClient: ActivityPubClient,
                                                activityPubProfile: String,
                                                logger: Logger) async throws -> FeaturedCollectionData {
        var featuredStatusIds = Set<String>()
        var featuredStatusNotes: [String: NoteDto] = [:]
        var visitedPageUrls = Set<String>()
        var nextPageUrl: URL? = featuredUrl
        var firstPage = true

        while let currentPageUrl = nextPageUrl {
            // We have to prevent loops (when remote will return same url in next property).
            let pageKey = currentPageUrl.absoluteString
            if visitedPageUrls.contains(pageKey) {
                logger.warning("Featured collection pagination loop detected for URL: '\(pageKey)'.")
                break
            }

            // Download ordered collection.
            visitedPageUrls.insert(pageKey)
            let collectionDto = try await activityPubClient.featuredCollection(url: currentPageUrl, activityPubProfile: activityPubProfile)

            var orderedObjects: [ObjectDto] = []
            var firstUrlString: String?
            var nextUrlString: String?

            // Add objects to the private variable.
            switch collectionDto {
            case .orderedCollection(let orderedCollection):
                orderedObjects = orderedCollection.orderedItems?.objects() ?? []
                firstUrlString = orderedCollection.first
            case .orderedCollectionPage(let orderedCollectionPage):
                orderedObjects = orderedCollectionPage.orderedItems.objects()
                nextUrlString = orderedCollectionPage.next
            }

            // Iterate via objects and add to id's or entities arrays.
            for orderedObject in orderedObjects {
                featuredStatusIds.insert(orderedObject.id)
                if let noteDto = orderedObject.object as? NoteDto {
                    featuredStatusNotes[orderedObject.id] = noteDto
                }
            }

            // Calculate url to get next data portion.
            if firstPage, let firstUrlString {
                nextPageUrl = self.resolveCollectionPageUrl(firstUrlString, relativeTo: currentPageUrl)
            } else if let nextUrlString {
                nextPageUrl = self.resolveCollectionPageUrl(nextUrlString, relativeTo: currentPageUrl)
            } else {
                nextPageUrl = nil
            }

            firstPage = false
        }

        return FeaturedCollectionData(statusIds: featuredStatusIds, statusNotes: featuredStatusNotes)
    }

    private func resolveCollectionPageUrl(_ value: String, relativeTo baseUrl: URL) -> URL? {
        if let url = URL(string: value), url.scheme != nil {
            return url
        }

        return URL(string: value, relativeTo: baseUrl)?.absoluteURL
    }
}
