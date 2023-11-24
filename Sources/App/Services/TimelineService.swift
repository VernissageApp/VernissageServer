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

protocol TimelineServiceType {
    func home(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> [Status]
    func `public`(on database: Database, linkableParams: LinkableParams, onlyLocal: Bool) async throws -> [Status]
    func hashtags(on database: Database, linkableParams: LinkableParams, hashtag: String, onlyLocal: Bool) async throws -> [Status]
}

final class TimelineService: TimelineServiceType {
    func home(on database: Database, for userId: Int64, linkableParams: LinkableParams) async throws -> [Status] {

        var query = UserStatus.query(on: database)
            .filter(\.$user.$id == userId)
            .with(\.$status) { status in
                status.with(\.$attachments) { attachment in
                    attachment.with(\.$originalFile)
                    attachment.with(\.$smallFile)
                    attachment.with(\.$exif)
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
                .filter(\.$status.$id > minId)
                .sort(\.$createdAt, .ascending)
        }
        else if let maxId = linkableParams.maxId?.toId() {
            query = query
                .filter(\.$status.$id < maxId)
                .sort(\.$createdAt, .descending)
        }
        else if let sinceId = linkableParams.sinceId?.toId() {
            query = query
                .filter(\.$status.$id > sinceId)
                .sort(\.$createdAt, .descending)
        } else {
            query = query
                .sort(\.$createdAt, .descending)
        }
        
        let statuses = try await query
            .limit(linkableParams.limit)
            .all()
            .map({ $0.status })

        return statuses.sorted(by: { $0.id ?? 0 > $1.id ?? 0 })
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
}
