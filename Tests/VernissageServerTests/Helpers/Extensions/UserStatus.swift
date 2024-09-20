//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

@testable import VernissageServer
import Vapor
import Fluent

extension Application {
    func createUserStatus(type: UserStatusType, user: User, status: Status) async throws -> UserStatus {
        let id = await ApplicationManager.shared.generateId()
        let userStatus = try UserStatus(id: id, type: type, userId: user.requireID(), statusId: status.requireID())
        _ = try await userStatus.save(on: self.db)
        return userStatus
    }
    
    func createUserStatus(type: UserStatusType, user: User, statuses: [Status]) async throws -> [UserStatus] {
        var userStatuses: [UserStatus] = []
        for status in statuses {
            let id = await ApplicationManager.shared.generateId()
            let userStatus = try UserStatus(id: id, type: type, userId: user.requireID(), statusId: status.requireID())
            try await userStatus.save(on: self.db)
            
            userStatuses.append(userStatus)
        }
        
        return userStatuses
    }
    
    func getAllUserStatuses(for statusId: Int64) async throws -> [UserStatus] {
        return try await UserStatus.query(on: self.db)
            .filter(\.$status.$id == statusId)
            .all()
    }
}
