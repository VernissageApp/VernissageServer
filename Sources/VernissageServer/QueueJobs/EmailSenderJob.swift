//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Queues
import Vapor

/// Background job that claims a persistent email delivery and hands it to the SMTP job.
struct EmailSenderJob: RetryableAsyncJob {
    typealias Payload = EmailSenderJobDto

    func dequeue(_ context: QueueContext, _ payload: EmailSenderJobDto) async throws {
        let executionContext = context.executionContext
        let emailDeliveryService = context.application.services.emailDeliveryService

        guard let emailJobDto = try await emailDeliveryService.prepareForSending(emailDeliveryId: payload.emailDeliveryId,
                                                                                  on: executionContext) else {
            return
        }

        context.logger.info("EmailSenderJob claimed email delivery '\(payload.emailDeliveryId)'.")

        do {
            try await context
                .queues(.emails)
                .dispatch(EmailJob.self, emailJobDto)
        } catch {
            let dispatchError = error

            do {
                try await emailDeliveryService.releaseAfterDispatchFailure(emailDeliveryId: payload.emailDeliveryId,
                                                                            processingToken: emailJobDto.processingToken,
                                                                            error: dispatchError,
                                                                            on: executionContext)
            } catch {
                await context.logger.store("Cannot release email delivery '\(payload.emailDeliveryId)' after enqueue failure.",
                                           error,
                                           on: context.application)
            }

            throw dispatchError
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: EmailSenderJobDto) async throws {
        await context.logger.store("EmailSenderJob error. Email delivery '\(payload.emailDeliveryId)'.",
                                   error,
                                   on: context.application)
    }
}
