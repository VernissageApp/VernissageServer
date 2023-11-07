//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

struct UserDeleterJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("UserDeleterJob dequeued job. User (id: '\(payload)').")
        
        let usersService = context.application.services.usersService
        try await usersService.deleteFromRemote(userId: payload, on: context)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        context.logger.error("UserDeleterJob error: \(error.localizedDescription). User (id: '\(payload)').")
    }
}
