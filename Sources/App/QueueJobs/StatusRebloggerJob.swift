//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

struct StatusRebloggerJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("StatusRebloggerJob dequeued job. Status (id: '\(payload)').")

        let statusesService = context.application.services.statusesService
        try await statusesService.send(reblog: payload, on: context)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        context.logger.error("StatusRebloggerJob error: \(error.localizedDescription). Status (id: '\(payload)').")
    }
}
