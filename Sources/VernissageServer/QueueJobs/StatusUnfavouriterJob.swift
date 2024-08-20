//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

/// Background job for unfavourite status.
struct StatusUnfavouriterJob: AsyncJob {
    typealias Payload = StatusUnfavouriteJobDto

    func dequeue(_ context: QueueContext, _ payload: StatusUnfavouriteJobDto) async throws {
        context.logger.info("StatusUnfavouriterJob dequeued job. Status favourite (id: '\(payload.statusFavouriteId)').")

        let statusesService = context.application.services.statusesService
        try await statusesService.send(unfavourite: payload, on: context)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: StatusUnfavouriteJobDto) async throws {
        context.logger.error("StatusUnfavouriterJob error: \(error.localizedDescription). Status favourite (id: '\(payload.statusFavouriteId)').")
    }
}
