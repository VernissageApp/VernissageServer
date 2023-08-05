//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import ActivityPubKit

struct ActivityPubUserOutboxJob: AsyncJob {
    typealias Payload = ActivityPubRequestDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubRequestDto) async throws {
        // This is where you would send the email
        let activityPubService = context.application.services.activityPubService
        context.logger.info("ActivityPubUserOutboxJob dequeued job. Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').")
                
        // Validate supported algorithm.
        try activityPubService.validateAlgorith(on: context, activityPubRequest: payload)
        
        // Validate signature.
        try await activityPubService.validateSignature(on: context, activityPubRequest: payload)
        
        switch payload.activity.type {
        case .delete:
            try activityPubService.delete(on: context, activity: payload.activity)
        case .follow:
            try await activityPubService.follow(on: context, activity: payload.activity)
        case .accept:
            try activityPubService.accept(on: context, activity: payload.activity)
        case .undo:
            try await activityPubService.undo(on: context, activity: payload.activity)
        default:
            context.logger.info("Unhandled action type: '\(payload.activity.type)'.")
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubRequestDto) async throws {
        // If you don't want to handle errors you can simply return. You can also omit this function entirely.
        context.logger.error("ActivityPubUserOutboxJob error: \(error.localizedDescription). Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').")
    }
}
