//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Queues
import Vapor

/// Background job responsible for sending a persistent migration Follow or Undo Follow item.
struct ActivityPubMigrationFollowRequesterJob: AsyncJob {
    typealias Payload = MigrationActivityPubEventItemJobDto

    func dequeue(_ context: QueueContext, _ payload: MigrationActivityPubEventItemJobDto) async throws {
        context.logger.info("ActivityPubMigrationFollowRequesterJob dequeued migration Follow item '\(payload.itemId)'.")
        try await context.application.services.accountMigrationActivityPubService.processFollow(itemId: payload.itemId,
                                                                                                  on: context.executionContext)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: MigrationActivityPubEventItemJobDto) async throws {
        await context.logger.store("ActivityPubMigrationFollowRequesterJob error. Migration Follow item '\(payload.itemId)'.",
                                   error,
                                   on: context.application)
    }
}
