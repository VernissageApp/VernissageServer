//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
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
        
        let statusesService = context.application.services.statusesService
        
        context.logger.info("StatusDeleterJob deleting status from remote server. Status (id: '\(payload.activityPubStatusId)').")
        try await statusesService.deleteFromRemote(statusActivityPubId: payload.activityPubStatusId, userId: payload.userId, on: context)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: StatusDeleteJobDto) async throws {
        context.logger.error("StatusDeleterJob error: \(error.localizedDescription). Status (id: '\(payload.activityPubStatusId)').")
    }
}
