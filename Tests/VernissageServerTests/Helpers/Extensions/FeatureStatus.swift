//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension FeaturedStatus {
    static func create(user: User, status: Status) async throws -> FeaturedStatus {
        let featuredStatus = try FeaturedStatus(statusId: status.requireID(), userId: user.requireID())
        _ = try await featuredStatus.save(on: SharedApplication.application().db)
        return featuredStatus
    }
    
    static func create(user: User, statuses: [Status]) async throws -> [FeaturedStatus] {
        var featuredStatuses: [FeaturedStatus] = []
        for status in statuses {
            let featuredStatus = try FeaturedStatus(statusId: status.requireID(), userId: user.requireID())
            try await featuredStatus.save(on: SharedApplication.application().db)
            
            featuredStatuses.append(featuredStatus)
        }
        
        return featuredStatuses
    }
}
