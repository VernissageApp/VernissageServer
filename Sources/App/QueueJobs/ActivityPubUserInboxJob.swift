//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import ActivityPubKit

struct ActivityPubUserInboxJob: AsyncJob {
    typealias Payload = ActivityDto

    func dequeue(_ context: QueueContext, _ payload: ActivityDto) async throws {
        // This is where you would send the email
        context.logger.info("ActivityPubUserInboxJob dequeued job. Activity (type: '\(payload.type)', id: '\(payload.id)').")
        
        // Validate blocked domains.
        
        // Validate signature.
        
        let activityPubService = context.application.services.activityPubService
        
        switch payload.type {
        case .delete:
            try activityPubService.delete(activity: payload)
        case .follow:
            try activityPubService.follow(activity: payload)
        case .accept:
            try activityPubService.accept(activity: payload)
        default:
            context.logger.info("Unhandled action type: '\(payload.type)'.")
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityDto) async throws {
        // If you don't want to handle errors you can simply return. You can also omit this function entirely.
        context.logger.error("ActivityPubUserInboxJob error: \(error.localizedDescription). Activity (type: '\(payload.type)', id: '\(payload.id)').")
    }
}
