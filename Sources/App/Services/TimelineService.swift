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
    func home(on database: Database, for userId: Int64, page: Int, size: Int) async throws -> [Status]
}

final class TimelineService: TimelineServiceType {
    func home(on database: Database, for userId: Int64, page: Int, size: Int) async throws -> [Status] {
        return try await UserStatus.query(on: database)
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
            }
            .sort(\.$createdAt, .descending)
            .offset(page * size)
            .limit(size)
            .all()
            .map({ $0.status })
    }
}
