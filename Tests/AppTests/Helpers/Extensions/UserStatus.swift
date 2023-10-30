//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import App
import Vapor
import Fluent

extension UserStatus {
    static func create(user: User, status: Status) async throws -> UserStatus {
        let userStatus = try UserStatus(userId: user.requireID(), statusId: status.requireID())
        _ = try await userStatus.save(on: SharedApplication.application().db)
        return userStatus
    }
    
    static func create(user: User, statuses: [Status]) async throws {
        for status in statuses {
            let userStatus = try UserStatus(userId: user.requireID(), statusId: status.requireID())
            _ = try await userStatus.save(on: SharedApplication.application().db)
        }
    }
}
