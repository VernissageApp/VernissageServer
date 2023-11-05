//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

struct StatusUnrebloggerJob: AsyncJob {
    typealias Payload = ActivityPubUnreblogDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubUnreblogDto) async throws {
        context.logger.info("StatusUnrebloggerJob dequeued job. Status (id: '\(payload)').")

        let statusesService = context.application.services.statusesService
        try await statusesService.send(unreblog: payload, on: context)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubUnreblogDto) async throws {
        context.logger.error("StatusUnrebloggerJob error: \(error.localizedDescription). Status (id: '\(payload)').")
    }
}
