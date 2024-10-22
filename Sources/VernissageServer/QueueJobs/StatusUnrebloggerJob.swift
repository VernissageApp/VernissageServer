//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

/// Background job for unreblog status.
struct StatusUnrebloggerJob: AsyncJob {
    typealias Payload = ActivityPubUnreblogDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubUnreblogDto) async throws {
        context.logger.info("StatusUnrebloggerJob dequeued job. Status (statusId: '\(payload.statusId)', orginalStatusId: '\(payload.orginalStatusId)', activityPubReblogId: '\(payload.activityPubReblogStatusId)').")

        let statusesService = context.application.services.statusesService
        try await statusesService.send(unreblog: payload, on: context)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubUnreblogDto) async throws {
        await context.logger.store( "StatusUnrebloggerJob erro. Status (statusId: '\(payload.statusId)', orginalStatusId: '\(payload.orginalStatusId)', activityPubReblogId: '\(payload.activityPubReblogStatusId)').", error, on: context.application)
    }
}
