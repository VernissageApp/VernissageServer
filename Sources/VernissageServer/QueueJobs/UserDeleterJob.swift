//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import Foundation
import Queues
import Smtp

/// Background job for user delete process.
struct UserDeleterJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("UserDeleterJob dequeued job. User (id: '\(payload)').")
        
        let usersService = context.application.services.usersService

        do {
            context.logger.info("UserDeleterJob deleting user from local database. User (id: '\(payload)').")
            try await usersService.delete(localUser: payload, on: context)
        } catch {
            context.logger.error("UserDeleterJob deleting from lodal database error: \(error.localizedDescription). User (id: '\(payload)').")
        }
        
        context.logger.info("UserDeleterJob deleting user from remote server. User (id: '\(payload)').")
        try await usersService.deleteFromRemote(userId: payload, on: context)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        context.logger.error("UserDeleterJob error: \(error.localizedDescription). User (id: '\(payload)').")
    }
}