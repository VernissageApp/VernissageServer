//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

struct StatusDeleterJob: AsyncJob {
    typealias Payload = Int64

    func dequeue(_ context: QueueContext, _ payload: Int64) async throws {
        context.logger.info("StatusDeleterJob dequeued job. Status (id: '\(payload)').")
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Int64) async throws {
        context.logger.error("StatusDeleterJob error: \(error.localizedDescription). Status (id: '\(payload)').")
    }
}
