//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

/// Background job for sending email.
struct EmailJob: AsyncJob {
    typealias Payload = EmailJobDto

    func dequeue(_ context: QueueContext, _ payload: EmailJobDto) async throws {
        let executionContext = context.executionContext
        let emailDeliveryService = context.application.services.emailDeliveryService

        guard let attempt = try await emailDeliveryService.beginAttempt(emailDeliveryId: payload.emailDeliveryId,
                                                                         processingToken: payload.processingToken,
                                                                         on: executionContext) else {
            return
        }

        context.logger.info("EmailJob started attempt '\(attempt.attempts)' for email delivery '\(payload.emailDeliveryId)' to '\(payload.email.to.address)'.")

        do {
            let emailFrom = payload.email.from
                ?? EmailAddressDto(address: context.application.settings.cached?.emailFromAddress ?? "",
                                   name: context.application.settings.cached?.emailFromName)
            let replyTo = payload.email.replyTo.map { EmailAddress(address: $0.address, name: $0.name) }

            let email = try Email(from: EmailAddress(address: emailFrom.address, name: emailFrom.name),
                                  to: [EmailAddress(address: payload.email.to.address, name: payload.email.to.name)],
                                  subject: payload.email.subject,
                                  body: payload.email.body,
                                  plain: "Please open email as HTML.",
                                  isBodyHtml: true,
                                  replyTo: replyTo)

            try await context.application.smtp.send(email)
            try await emailDeliveryService.markSucceeded(emailDeliveryId: payload.emailDeliveryId,
                                                          processingToken: attempt.processingToken,
                                                          on: executionContext)
        } catch {
            let sendingError = error

            do {
                try await emailDeliveryService.markFailed(emailDeliveryId: payload.emailDeliveryId,
                                                           processingToken: attempt.processingToken,
                                                           error: sendingError,
                                                           on: executionContext)
            } catch {
                await context.logger.store("Cannot persist failure of email delivery '\(payload.emailDeliveryId)'.",
                                           error,
                                           on: context.application)
            }

            throw sendingError
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: EmailJobDto) async throws {
        await context.logger.store("EmailJob error. Email delivery '\(payload.emailDeliveryId)' to '\(payload.email.to.address)'.",
                                   error,
                                   on: context.application)
    }
}
