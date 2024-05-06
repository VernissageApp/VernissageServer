//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp

/// Background job for sending WebPush notifications.
struct WebPushSenderJob: AsyncJob {
    typealias Payload = WebPush

    func dequeue(_ context: QueueContext, _ payload: WebPush) async throws {
        context.logger.info("WebPushSenderJob dequeued job. Notification (from: '\(payload.fromUserId)', to: '\(payload.toUserId)', type: '\(payload.notificationType)').")
        
        // Send notification via WebPush service.
        try await context.application.services.webPushService.send(webPush: payload, on: context)
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: WebPush) async throws {
        context.logger.error("WebPushSenderJob error: \(error.localizedDescription).  Notification (from: '\(payload.fromUserId)', to: '\(payload.toUserId)', type: '\(payload.notificationType)').")
    }
}
