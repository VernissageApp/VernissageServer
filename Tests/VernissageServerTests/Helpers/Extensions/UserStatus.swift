//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension UserStatus {
    static func create(type: UserStatusType, user: User, status: Status) async throws -> UserStatus {
        let userStatus = try UserStatus(type: type, userId: user.requireID(), statusId: status.requireID())
        _ = try await userStatus.save(on: SharedApplication.application().db)
        return userStatus
    }
    
    static func create(type: UserStatusType, user: User, statuses: [Status]) async throws -> [UserStatus] {
        var userStatuses: [UserStatus] = []
        for status in statuses {
            let userStatus = try UserStatus(type: type, userId: user.requireID(), statusId: status.requireID())
            try await userStatus.save(on: SharedApplication.application().db)
            
            userStatuses.append(userStatus)
        }
        
        return userStatuses
    }
}
