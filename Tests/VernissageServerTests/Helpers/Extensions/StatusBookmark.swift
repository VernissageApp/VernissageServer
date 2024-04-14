//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension StatusBookmark {
    static func create(user: User, statuses: [Status]) async throws -> [StatusBookmark] {
        var userBookmarks: [StatusBookmark] = []
        for status in statuses {
            let statusBookmark = try StatusBookmark(statusId: status.requireID(), userId: user.requireID())
            try await statusBookmark.save(on: SharedApplication.application().db)
            
            userBookmarks.append(statusBookmark)
        }
        
        return userBookmarks
    }
}
