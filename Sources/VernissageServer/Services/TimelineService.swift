//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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
protocol TimelineServiceType {
    func home(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> LinkableResult<Status>
    func `public`(on database: Database, linkableParams: LinkableParams, onlyLocal: Bool) async throws -> [Status]
    func category(on database: Database, linkableParams: LinkableParams, categoryId: Int64, onlyLocal: Bool) async throws -> [Status]
    func hashtags(on database: Database, linkableParams: LinkableParams, hashtag: String, onlyLocal: Bool) async throws -> [Status]
    func featured(on database: Database, linkableParams: LinkableParams, onlyLocal: Bool) async throws -> LinkableResult<Status>
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
    
    func featured(on database: Database, linkableParams: LinkableParams, onlyLocal: Bool = false) async throws -> LinkableResult<Status> {
        var query = FeaturedStatus.query(on: database)
            .filter(\.$createdAt > Date.monthAgo)
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
}
