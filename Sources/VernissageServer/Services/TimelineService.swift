//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import FluentSQL

extension Application.Services {
    struct TimelineServiceKey: StorageKey {
        typealias Value = TimelineServiceType
    }

    var timelineService: TimelineServiceType {
        get {
            self.application.storage[TimelineServiceKey.self] ?? TimelineService()
        }
        nonmutating set {
            self.application.storage[TimelineServiceKey.self] = newValue
        }
    }
}

@_documentation(visibility: private)
protocol TimelineServiceType: Sendable {
    /// Returns statuses for the user's home timeline.
    /// - Parameters:
    ///   - userId: Unique identifier for the user.
    ///   - linkableParams: Paging and filtering parameters.
    ///   - executionContext: Context to perform the query on.
    /// - Returns: Linkable result with statuses from the home timeline.
    /// - Throws: Database errors.
    func home(for userId: Int64, linkableParams: LinkableParams, on executionContext: ExecutionContext) async throws -> LinkableResult<Status>
    
    /// Returns statuses bookmarked by the user.
    /// - Parameters:
    ///   - userId: Unique identifier for the user.
    ///   - linkableParams: Paging and filtering parameters.
    ///   - executionContext: Context to perform the query on.
    /// - Returns: Linkable result with bookmarked statuses.
    /// - Throws: Database errors.
    func bookmarks(for userId: Int64, linkableParams: LinkableParams, on executionContext: ExecutionContext) async throws -> LinkableResult<Status>
    
    /// Returns statuses favourited by the user.
    /// - Parameters:
    ///   - userId: Unique identifier for the user.
    ///   - linkableParams: Paging and filtering parameters.
    ///   - executionContext: Context to perform the query on.
    /// - Returns: Linkable result with favourited statuses.
    /// - Throws: Database errors.
    func favourites(for userId: Int64, linkableParams: LinkableParams, on executionContext: ExecutionContext) async throws -> LinkableResult<Status>
    
    /// Returns public statuses with paging and optional filtering for local statuses.
    /// - Parameters:
    ///   - linkableParams: Paging and filtering parameters.
    ///   - onlyLocal: Whether to include only local statuses.
    ///   - userId: Timeline filtered in context of user (filtered statuses from muted users  for example).
    ///   - executionContext: Context to perform the query on.
    /// - Returns: Array of public statuses.
    /// - Throws: Database errors.
    func `public`(linkableParams: LinkableParams, onlyLocal: Bool, forUserId userId: Int64?, on executionContext: ExecutionContext) async throws -> [Status]
    
    /// Returns public statuses for a given category.
    /// - Parameters:
    ///   - linkableParams: Paging and filtering parameters.
    ///   - categoryId: Category identifier.
    ///   - onlyLocal: Whether to include only local statuses.
    ///   - userId: Timeline filtered in context of user (filtered statuses from muted users  for example).
    ///   - executionContext: Context to perform the query on.
    /// - Returns: Array of statuses for the category.
    /// - Throws: Database errors.
    func category(linkableParams: LinkableParams, categoryId: Int64, onlyLocal: Bool, forUserId userId: Int64?, on executionContext: ExecutionContext) async throws -> [Status]
    
    /// Returns public statuses for a given hashtag.
    /// - Parameters:
    ///   - linkableParams: Paging and filtering parameters.
    ///   - hashtag: Hashtag string (normalized).
    ///   - onlyLocal: Whether to include only local statuses.
    ///   - userId: Timeline filtered in context of user (filtered statuses from muted users  for example).
    ///   - executionContext: Context to perform the query on.
    /// - Returns: Array of statuses for the hashtag.
    /// - Throws: Database errors.
    func hashtags(linkableParams: LinkableParams, hashtag: String, onlyLocal: Bool, forUserId userId: Int64?, on executionContext: ExecutionContext) async throws -> [Status]
    
    /// Returns featured statuses within the last year.
    /// - Parameters:
    ///   - linkableParams: Paging and filtering parameters.
    ///   - onlyLocal: Whether to include only local statuses.
    ///   - executionContext: Context to perform the query on.
    /// - Returns: Linkable result with featured statuses.
    /// - Throws: Database errors.
    func featuredStatuses(linkableParams: LinkableParams, onlyLocal: Bool, on executionContext: ExecutionContext) async throws -> LinkableResult<Status>
    
    /// Returns featured users within the last year.
    /// - Parameters:
    ///   - linkableParams: Paging and filtering parameters.
    ///   - onlyLocal: Whether to include only local users.
    ///   - executionContext: Context to perform the query on.
    /// - Returns: Linkable result with featured users.
    /// - Throws: Database errors.
    func featuredUsers(linkableParams: LinkableParams, onlyLocal: Bool, on executionContext: ExecutionContext) async throws -> LinkableResult<User>
    
    /// Removes from user's private timeline all statuses which has been created by followed user
    /// (directly or boosted by someone else).
    /// - Parameters:
    ///   - userId: owner of the timeline.
    ///   - authorId: author of statuses to delete.
    ///   - executionContext: Context to perform the query on.
    /// - Throws: Database errors.
    func removeStatusesFromHomeTimeline(forUserId userId: Int64, byUserId authorId: Int64, on executionContext: ExecutionContext) async throws

    /// Removes from user's private timeline all statuses which has been reblogged by the reblog user
    /// (statuses created by other users, but reblogged by specific user).
    /// - Parameters:
    ///   - userId: owner of the timeline.
    ///   - authorId: author of statuses to delete.
    ///   - executionContext: Context to perform the query on.
    /// - Throws: Database errors.
    func removeReblogsFromTimeline(forUserId userId: Int64, byUserId authorId: Int64, on executionContext: ExecutionContext) async throws
}

/// A service for managing main timelines.
final class TimelineService: TimelineServiceType {
    func home(for userId: Int64, linkableParams: LinkableParams, on executionContext: ExecutionContext) async throws -> LinkableResult<Status> {

        var query = UserStatus.query(on: executionContext.db)
            .filter(\.$user.$id == userId)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$originalHdrFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$mentions)
                .with(\.$user)
                .with(\.$category)
            }
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let userStatuses = try await query
            .limit(linkableParams.limit)
            .all()

        let sortedUserStatuses = userStatuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
        
        return LinkableResult(
            maxId: sortedUserStatuses.last?.stringId(),
            minId: sortedUserStatuses.first?.stringId(),
            data: sortedUserStatuses.map({ $0.status })
        )
    }
    
    func bookmarks(for userId: Int64, linkableParams: LinkableParams, on executionContext: ExecutionContext) async throws -> LinkableResult<Status> {

        var query = StatusBookmark.query(on: executionContext.db)
            .filter(\.$user.$id == userId)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$originalHdrFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$mentions)
                .with(\.$user)
                .with(\.$category)
            }
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let bookmarkedStatuses = try await query
            .limit(linkableParams.limit)
            .all()

        let sortedBookmarkedStatuses = bookmarkedStatuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
        
        return LinkableResult(
            maxId: sortedBookmarkedStatuses.last?.stringId(),
            minId: sortedBookmarkedStatuses.first?.stringId(),
            data: sortedBookmarkedStatuses.map({ $0.status })
        )
    }
    
    func favourites(for userId: Int64, linkableParams: LinkableParams, on executionContext: ExecutionContext) async throws -> LinkableResult<Status> {

        var query = StatusFavourite.query(on: executionContext.db)
            .filter(\.$user.$id == userId)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$originalHdrFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$mentions)
                .with(\.$user)
                .with(\.$category)
            }
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let favouritedStatuses = try await query
            .limit(linkableParams.limit)
            .all()

        let sortedFavouritedStatuses = favouritedStatuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
        
        return LinkableResult(
            maxId: sortedFavouritedStatuses.last?.stringId(),
            minId: sortedFavouritedStatuses.first?.stringId(),
            data: sortedFavouritedStatuses.map({ $0.status })
        )
    }
    
    func `public`(linkableParams: LinkableParams,
                  onlyLocal: Bool = false,
                  forUserId userId: Int64? = nil,
                  on executionContext: ExecutionContext
    ) async throws -> [Status] {
        let mutedUserIds = try await self.mutedUsers(forUserId: userId, on: executionContext)
        
        var query = Status.query(on: executionContext.db)
            .filter(\.$visibility == .public)
            .filter(\.$replyToStatus.$id == nil)
            .filter(\.$reblog.$id == nil)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$user)
            .with(\.$category)
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        if onlyLocal {
            query = query
                .filter(\.$isLocal == true)
        }
        
        if mutedUserIds.isEmpty == false {
            query = query
                .filter(\.$user.$id !~ mutedUserIds)
        }
        
        let statuses = try await query
            .limit(linkableParams.limit)
            .all()

        return statuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
    }
    
    func category(linkableParams: LinkableParams,
                  categoryId: Int64,
                  onlyLocal: Bool = false,
                  forUserId userId: Int64? = nil,
                  on executionContext: ExecutionContext
    ) async throws -> [Status] {
        let mutedUserIds = try await self.mutedUsers(forUserId: userId, on: executionContext)

        var query = Status.query(on: executionContext.db)
            .filter(\.$visibility == .public)
            .filter(\.$replyToStatus.$id == nil)
            .filter(\.$reblog.$id == nil)
            .filter(\.$category.$id == categoryId)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$user)
            .with(\.$category)
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        if onlyLocal {
            query = query
                .filter(\.$isLocal == true)
        }
        
        if mutedUserIds.isEmpty == false {
            query = query
                .filter(\.$user.$id !~ mutedUserIds)
        }
        
        let statuses = try await query
            .limit(linkableParams.limit)
            .all()

        return statuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
    }
    
    func hashtags(linkableParams: LinkableParams,
                  hashtag: String,
                  onlyLocal: Bool = false,
                  forUserId userId: Int64? = nil,
                  on executionContext: ExecutionContext
    ) async throws -> [Status] {
        let mutedUserIds = try await self.mutedUsers(forUserId: userId, on: executionContext)

        var query = Status.query(on: executionContext.db)
            .join(StatusHashtag.self, on: \Status.$id == \StatusHashtag.$status.$id)
            .filter(\.$visibility == .public)
            .filter(\.$replyToStatus.$id == nil)
            .filter(\.$reblog.$id == nil)
            .filter(StatusHashtag.self, \.$hashtagNormalized == hashtag.uppercased())
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$originalHdrFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
            .with(\.$mentions)
            .with(\.$user)
            .with(\.$category)
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        if onlyLocal {
            query = query
                .filter(\.$isLocal == true)
        }
        
        if mutedUserIds.isEmpty == false {
            query = query
                .filter(\.$user.$id !~ mutedUserIds)
        }
        
        let statuses = try await query
            .limit(linkableParams.limit)
            .all()

        return statuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
    }
    
    func featuredStatuses(linkableParams: LinkableParams, onlyLocal: Bool = false, on executionContext: ExecutionContext) async throws -> LinkableResult<Status> {
        var query = FeaturedStatus.query(on: executionContext.db)
            .filter(\.$createdAt > Date.yearAgo)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$originalHdrFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
                .with(\.$mentions)
                .with(\.$user)
                .with(\.$category)
            }
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let featuredStatuses = try await query
            .limit(linkableParams.limit)
            .all()
        
        let sortedFeaturedStatuses = featuredStatuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
        
        return LinkableResult(
            maxId: sortedFeaturedStatuses.last?.stringId(),
            minId: sortedFeaturedStatuses.first?.stringId(),
            data: sortedFeaturedStatuses.map({ $0.status })
        )
    }
    
    func featuredUsers(linkableParams: LinkableParams, onlyLocal: Bool = false, on executionContext: ExecutionContext) async throws -> LinkableResult<User> {
        var query = FeaturedUser.query(on: executionContext.db)
            .with(\.$featuredUser) { featuredUser in
                featuredUser
                    .with(\.$hashtags)
                    .with(\.$flexiFields)
                    .with(\.$roles)
            }
            .join(User.self, on: \User.$id == \FeaturedUser.$featuredUser.$id)
            .filter(User.self, \.$deletedAt == nil)
        
        if let minId = linkableParams.minId?.toId() {
            query = query
                .filter(\.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let featuredUsers = try await query
            .limit(linkableParams.limit)
            .all()
        
        let sortedFeaturedUsers = featuredUsers.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
        
        return LinkableResult(
            maxId: sortedFeaturedUsers.last?.stringId(),
            minId: sortedFeaturedUsers.first?.stringId(),
            data: sortedFeaturedUsers.map({ $0.featuredUser })
        )
    }
    
    func removeStatusesFromHomeTimeline(forUserId userId: Int64, byUserId authorId: Int64, on executionContext: ExecutionContext) async throws {
        guard let sql = executionContext.db as? SQLDatabase else {
            return
        }
        
        // Delete all statuses from timeline which has been added directly on the timeline by author (via follow).
        try await sql.raw("""
            DELETE FROM \(ident: UserStatus.schema) WHERE \(ident: "id") IN (
                SELECT \(ident: "us").\(ident: "id") FROM \(ident: UserStatus.schema) \(ident: "us")
                INNER JOIN \(ident: Status.schema) \(ident: "s1") ON \(ident: "us").\(ident: "statusId") = \(ident: "s1").\(ident: "id")
                WHERE \(ident: "us").\(ident: "userId") = \(bind: userId)
                  AND \(ident: "s1").\(ident: "userId") = \(bind: authorId)
                  AND \(ident: "s1").\(ident: "reblogId") IS NULL
            )
        """).run()
        
        // Delete all statuses from timeline which are reblogs done by user's which we follow and status is created by author (via reblogs).
        try await sql.raw("""
            DELETE FROM \(ident: UserStatus.schema) WHERE \(ident: "id") IN (
                SELECT \(ident: "us").\(ident: "id") FROM \(ident: UserStatus.schema) \(ident: "us")
                INNER JOIN \(ident: Status.schema) \(ident: "s1") ON \(ident: "us").\(ident: "statusId") = \(ident: "s1").\(ident: "id")
                INNER JOIN \(ident: Status.schema) \(ident: "s2") ON \(ident: "s1").\(ident: "reblogId") = \(ident: "s2").\(ident: "id")
                WHERE \(ident: "us").\(ident: "userId") = \(bind: userId)
                  AND \(ident: "s2").\(ident: "userId") = \(bind: authorId)
            )
        """).run()
    }
    
    func removeReblogsFromTimeline(forUserId userId: Int64, byUserId authorId: Int64, on executionContext: ExecutionContext) async throws {
        guard let sql = executionContext.db as? SQLDatabase else {
            return
        }
        
        // Delete all statuses from timeline which has been added because author reblogged them.
        try await sql.raw("""
            DELETE FROM \(ident: UserStatus.schema) WHERE \(ident: "id") IN (
                SELECT \(ident: "us").\(ident: "id") FROM \(ident: UserStatus.schema) \(ident: "us")
                INNER JOIN \(ident: Status.schema) \(ident: "s1") ON \(ident: "us").\(ident: "statusId") = \(ident: "s1").\(ident: "id")
                WHERE \(ident: "us").\(ident: "userId") = \(bind: userId)
                  AND \(ident: "s1").\(ident: "userId") = \(bind: authorId)
                  AND \(ident: "s1").\(ident: "reblogId") IS NOT NULL
            )
        """).run()
    }
    
    private func mutedUsers(forUserId userId: Int64?, on executionContext: ExecutionContext) async throws -> [Int64] {
        guard let userId else {
            return []
        }
        
        let userMutesService = executionContext.services.userMutesService
        let mutedUserIds = try await userMutesService.mutedUsers(forUserId: userId, on: executionContext.db)
        return mutedUserIds
    }
}
