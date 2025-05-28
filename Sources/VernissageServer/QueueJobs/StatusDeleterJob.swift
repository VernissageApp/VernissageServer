//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

/// Background job for delete status.
struct StatusDeleterJob: AsyncJob {
    typealias Payload = StatusDeleteJobDto

    func dequeue(_ context: QueueContext, _ payload: StatusDeleteJobDto) async throws {
        context.logger.info("StatusDeleterJob dequeued job. Status (id: '\(payload.activityPubStatusId)').")
        
        context.logger.info("StatusDeleterJob deleting status from remote server. Status (id: '\(payload.activityPubStatusId)').")
        let statusesService = context.application.services.statusesService
        try await statusesService.deleteFromRemote(statusActivityPubId: payload.activityPubStatusId,
                                                   userId: payload.userId,
                                                   statusId: payload.statusId,
                                                   on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: StatusDeleteJobDto) async throws {
        await context.logger.store("StatusDeleterJob error. Status (id: '\(payload.activityPubStatusId)').", error, on: context.application)
    }
}
