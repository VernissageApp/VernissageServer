//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Foundation
import Queues
import Smtp
import Vapor

/// Re-enqueues local statuses for which the ActivityPub Create event was not created.
struct RecoverMissingStatusActivityPubEventsJob: AsyncScheduledJob {
    private static let batchSize = 100
    private let jobId = "RecoverMissingStatusActivityPubEventsJob"

    func run(context: QueueContext) async throws {
        guard context.application.settings.cached?.rescheduleActivityPubJobEnabled != false else {
            context.logger.info("[RecoverMissingStatusActivityPubEventsJob] Job is disabled in settings.")
            return
        }

        context.logger.info("[RecoverMissingStatusActivityPubEventsJob] Job is running.")

        guard try await self.single(jobId: self.jobId, lockFor: 55 * 60, on: context) else {
            return
        }

        let thirtyMinutesAgo = Date.now.addingTimeInterval(-30 * 60)
        let statuses = try await Status.query(on: context.application.db)
            .filter(\.$isLocal == true)
            .filter(\.$visibility ~~ [.public, .followers])
            .filter(\.$reblog.$id == nil)
            .filter(\.$createdAt > Date.weekAgo)
            .filter(\.$createdAt < thirtyMinutesAgo)
            .join(
                StatusActivityPubEvent.self,
                on: \Status.$id == \StatusActivityPubEvent.$status.$id
                    && \StatusActivityPubEvent.$type == StatusActivityPubEventType.create,
                method: .left
            )
            .filter(StatusActivityPubEvent.self, \.$createdAt == nil)
            .field(\.$id)
            .sort(\.$createdAt, .ascending)
            .limit(Self.batchSize)
            .all()

        let statusIds = statuses.compactMap(\.id)
        context.logger.info("[RecoverMissingStatusActivityPubEventsJob] Job found \(statusIds.count) statuses to recover.")

        for statusId in statusIds {
            do {
                try await context
                    .queues(.statusSender)
                    .dispatch(StatusCreaterJob.self, statusId, maxRetryCount: 3)
            } catch {
                await context.logger.store(
                    "[RecoverMissingStatusActivityPubEventsJob] Cannot enqueue status '\(statusId)'.",
                    error,
                    on: context.application
                )
            }
        }

        context.logger.info("[RecoverMissingStatusActivityPubEventsJob] Job finished processing.")
    }
}
