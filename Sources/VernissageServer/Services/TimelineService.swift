//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent

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
    func home(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<Status>
    func bookmarks(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<Status>
    func favourites(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<Status>
    func `public`(on database: Database, linkableParams: LinkableParams, onlyLocal: Bool) async throws -> [Status]
    func category(on database: Database, linkableParams: LinkableParams, categoryId: Int64, onlyLocal: Bool) async throws -> [Status]
    func hashtags(on database: Database, linkableParams: LinkableParams, hashtag: String, onlyLocal: Bool) async throws -> [Status]
    func featuredStatuses(on database: Database, linkableParams: LinkableParams, onlyLocal: Bool) async throws -> LinkableResult<Status>
    func featuredUsers(on database: Database, linkableParams: LinkableParams, onlyLocal: Bool) async throws -> LinkableResult<User>
}

/// A service for managing main timelines.
final class TimelineService: TimelineServiceType {
    func home(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<Status> {

        var query = UserStatus.query(on: database)
            .filter(\.$user.$id == userId)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
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
    
    func bookmarks(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<Status> {

        var query = StatusBookmark.query(on: database)
            .filter(\.$user.$id == userId)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
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
    
    func favourites(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<Status> {

        var query = StatusFavourite.query(on: database)
            .filter(\.$user.$id == userId)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
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
    
    func `public`(on database: Database, linkableParams: LinkableParams, onlyLocal: Bool = false) async throws -> [Status] {

        var query = Status.query(on: database)
            .filter(\.$visibility == .public)
            .filter(\.$replyToStatus.$id == nil)
            .filter(\.$reblog.$id == nil)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
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
        
        let statuses = try await query
            .limit(linkableParams.limit)
            .all()

        return statuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
    }
    
    func category(on database: Database, linkableParams: LinkableParams, categoryId: Int64, onlyLocal: Bool = false) async throws -> [Status] {

        var query = Status.query(on: database)
            .filter(\.$visibility == .public)
            .filter(\.$replyToStatus.$id == nil)
            .filter(\.$reblog.$id == nil)
            .filter(\.$category.$id == categoryId)
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
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
        
        let statuses = try await query
            .limit(linkableParams.limit)
            .all()

        return statuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
    }
    
    func hashtags(on database: Database, linkableParams: LinkableParams, hashtag: String, onlyLocal: Bool = false) async throws -> [Status] {

        var query = Status.query(on: database)
            .join(StatusHashtag.self, on: \Status.$id == \StatusHashtag.$status.$id)
            .filter(\.$visibility == .public)
            .filter(\.$replyToStatus.$id == nil)
            .filter(\.$reblog.$id == nil)
            .filter(StatusHashtag.self, \.$hashtagNormalized == hashtag.uppercased())
            .with(\.$attachments) { attachment in
                attachment.with(\.$originalFile)
                attachment.with(\.$smallFile)
                attachment.with(\.$exif)
                attachment.with(\.$license)
                attachment.with(\.$location) { location in
                    location.with(\.$country)
                }
            }
            .with(\.$hashtags)
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
        
        let statuses = try await query
            .limit(linkableParams.limit)
            .all()

        return statuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
    }
    
    func featuredStatuses(on database: Database, linkableParams: LinkableParams, onlyLocal: Bool = false) async throws -> LinkableResult<Status> {
        var query = FeaturedStatus.query(on: database)
            .filter(\.$createdAt > Date.yearAgo)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
                    attachment.with(\.$license)
                    attachment.with(\.$location) { location in
                        location.with(\.$country)
                    }
                }
                .with(\.$hashtags)
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
    
    func featuredUsers(on database: Database, linkableParams: LinkableParams, onlyLocal: Bool = false) async throws -> LinkableResult<User> {
        var query = FeaturedUser.query(on: database)
            .filter(\.$createdAt > Date.yearAgo)
            .with(\.$featuredUser) { featuredUser in
                featuredUser
                    .with(\.$hashtags)
                    .with(\.$flexiFields)
                    .with(\.$roles)
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
}
