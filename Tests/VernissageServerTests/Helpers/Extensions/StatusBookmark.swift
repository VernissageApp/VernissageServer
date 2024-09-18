//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Application {
    func createStatusBookmark(user: User, statuses: [Status]) async throws -> [StatusBookmark] {
        var userBookmarks: [StatusBookmark] = []
        for status in statuses {
            let statusBookmark = try StatusBookmark(statusId: status.requireID(), userId: user.requireID())
            try await statusBookmark.save(on: self.db)
            
            userBookmarks.append(statusBookmark)
        }
        
        return userBookmarks
    }
}
