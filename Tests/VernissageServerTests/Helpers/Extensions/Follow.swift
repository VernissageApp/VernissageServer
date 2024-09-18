//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension Application {
    func createFollow(
        sourceId: Int64,
        targetId: Int64,
        approved: Bool = true) async throws -> Follow {

        let follow = Follow(sourceId: sourceId, targetId: targetId, approved: approved, activityId: nil)
        
        _ = try await follow.save(on: self.db)

        return follow
    }
    
    func getFollow(sourceId: Int64, targetId: Int64) async throws -> Follow? {
        return try await Follow.query(on: self.db)
            .filter(\.$source.$id == sourceId)
            .filter(\.$target.$id == targetId)
            .first()
    }
}
