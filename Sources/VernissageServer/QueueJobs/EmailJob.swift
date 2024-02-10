//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

/// Background job for sending email.
struct EmailJob: AsyncJob {
    typealias Payload = EmailDto

    func dequeue(_ context: QueueContext, _ payload: EmailDto) async throws {
        context.logger.info("EmailJob dequeued job. Email (address: '\(payload.to.address)', id: '\(payload.subject)').")
        
        let emailFromAddress = context.application.settings.cached?.emailFromAddress ?? ""
        let emailFromName = context.application.settings.cached?.emailFromName ?? ""
        
        let email = try Email(from: EmailAddress(address: emailFromAddress, name: emailFromName),
                              to: [EmailAddress(address: payload.to.address, name: payload.to.name)],
                              subject: payload.subject,
                              body: payload.body,
                              isBodyHtml: true)

        try await context.application.smtp.send(email)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: EmailDto) async throws {
        context.logger.error("EmailJob error: \(error.localizedDescription). Email (address: '\(payload.to)', id: '\(payload.subject)').")
    }
}
