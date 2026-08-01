//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues

/// Background job responsible for sending account migration requests to remote instances.
struct ActivityPubMoveRequesterJob: AsyncJob {
    typealias Payload = MigrationActivityPubEventItemJobDto

    func dequeue(_ context: QueueContext, _ payload: MigrationActivityPubEventItemJobDto) async throws {
        context.logger.info("ActivityPubMoveRequesterJob dequeued migration Move item '\(payload.itemId)'.")
        try await context.application.services.accountMigrationActivityPubService.processMove(itemId: payload.itemId,
                                                                                                on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: MigrationActivityPubEventItemJobDto) async throws {
        await context.logger.store("ActivityPubMoveRequesterJob error. Migration Move item '\(payload.itemId)'.",
                                   error,
                                   on: context.application)
    }
}
