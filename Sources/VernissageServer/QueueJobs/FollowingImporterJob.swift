//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

/// Background job for importing follwing accounts.
struct FollowingImporterJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("FollowingImporterJob dequeued job. Following import (id: '\(payload)').")
        
        let followingImportsService = context.application.services.followingImportsService
        try await followingImportsService.run(for: payload, on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: EmailDto) async throws {
        await context.logger.store("FollowingImporterJob error. Following import (id: '\(payload.to)').", error, on: context.application)
    }
}
