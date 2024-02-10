//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import ActivityPubKit

/// Bakcground job resposible for consumig all request done to Activity Pub user outbox.
struct ActivityPubUserOutboxJob: AsyncJob {
    typealias Payload = ActivityPubRequestDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubRequestDto) async throws {
        context.logger.info("ActivityPubUserOutboxJob dequeued job. Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').")
                
        switch payload.activity.type {
        default:
            context.logger.info("Unhandled action type: '\(payload.activity.type)'.")
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubRequestDto) async throws {
        context.logger.error("ActivityPubUserOutboxJob error: \(error.localizedDescription). Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').")
    }
}
