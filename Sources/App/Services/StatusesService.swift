//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import FluentSQL
import Queues

extension Application.Services {
    struct StatusesServiceKey: StorageKey {
        typealias Value = StatusesServiceType
    }

    var statusesService: StatusesServiceType {
        get {
            self.application.storage[StatusesServiceKey.self] ?? StatusesService()
        }
        nonmutating set {
            self.application.storage[StatusesServiceKey.self] = newValue
        }
    }
}

protocol StatusesServiceType {
    func count(on database: Database, for userId: Int64) async throws -> Int
    func updateStatusCount(on database: Database, for userId: Int64) async throws
    func send(status statusId: Int64, on context: QueueContext) async throws
}

final class StatusesService: StatusesServiceType {
    func count(on database: Database, for userId: Int64) async throws -> Int {
        return try await Status.query(on: database).filter(\.$user.$id == userId).count()
    }
    
    func updateStatusCount(on database: Database, for userId: Int64) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }

        try await sql.raw("""
            UPDATE \(ident: User.schema)
            SET \(ident: "statusesCount") = (SELECT count(1) FROM \(ident: Status.schema) WHERE \(ident: "userId") = \(bind: userId))
            WHERE \(ident: "id") = \(bind: userId)
        """).run()
    }
    
    func send(status statusId: Int64, on context: QueueContext) async throws {
        guard let status = try await Status.query(on: context.application.db)
            .filter(\.$id == statusId)
            .with(\.$user)
            .first() else {
            throw EntityNotFoundError.statusNotFound
        }
        
        switch status.visibility {
        case .public, .followers:
            let ownerUserStatus = try UserStatus(userId: status.user.requireID(), statusId: statusId)
            try await ownerUserStatus.create(on: context.application.db)
            
            try await Follow.query(on: context.application.db)
                .filter(\.$target.$id == status.$user.id)
                .filter(\.$approved == true)
                .chunk(max: 100) { follows in
                    for follow in follows {
                        Task {
                            do {
                                switch follow {
                                case .success(let success):
                                    let userStatus = UserStatus(userId: success.$source.id, statusId: statusId)
                                    try await userStatus.create(on: context.application.db)
                                case .failure(let failure):
                                    context.logger.error("Status \(statusId) cannot be added to the user. Error: \(failure.localizedDescription).")
                                }
                            } catch {
                                context.logger.error("Status \(statusId) cannot be added to the user. Error: \(error.localizedDescription).")
                            }
                        }
                    }
                }
        case .mentioned:
            let userIds = self.getMentionedUsers(for: status)
            for userId in userIds {
                let userStatus = UserStatus(userId: userId, statusId: statusId)
                try await userStatus.create(on: context.application.db)
            }
        }
    }
    
    private func getMentionedUsers(for status: Status) -> [Int64] {
        return []
    }
}
