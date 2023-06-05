//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues

struct EmailJob: AsyncJob {
    typealias Payload = EmailDto

    func dequeue(_ context: QueueContext, _ payload: EmailDto) async throws {
        // This is where you would send the email
        context.logger.info("EmailJob dequeued job. Email (address: '\(payload.to)', id: '\(payload.subject)').")
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: EmailDto) async throws {
        // If you don't want to handle errors you can simply return. You can also omit this function entirely.
        context.logger.error("EmailJob error: \(error.localizedDescription). Email (address: '\(payload.to)', id: '\(payload.subject)').")
    }
}
