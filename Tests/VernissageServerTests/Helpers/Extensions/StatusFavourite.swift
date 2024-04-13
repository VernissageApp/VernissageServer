//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import XCTVapor
import Fluent

extension StatusFavourite {
    static func get(statusId: Int64) async throws -> StatusFavourite? {
        return try await StatusFavourite.query(on: SharedApplication.application().db)
            .filter(\.$status.$id == statusId)
            .first()
    }
    
    static func create(statusId: Int64, userId: Int64) async throws -> StatusFavourite {
        let statusFavourite = StatusFavourite(statusId: statusId, userId: userId)
        try await statusFavourite.save(on: SharedApplication.application().db)
        
        return statusFavourite
    }
}
