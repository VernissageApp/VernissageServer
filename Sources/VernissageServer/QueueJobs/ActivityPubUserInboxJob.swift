//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import ActivityPubKit

/// Bakcground job resposible for consumig all request done to Activity Pub user inbox.
struct ActivityPubUserInboxJob: AsyncJob {
    typealias Payload = ActivityPubRequestDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubRequestDto) async throws {
        context.logger.info("ActivityPubUserInboxJob dequeued job. Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').")
        
        let activityPubService = context.application.services.activityPubService
        let activityPubSignatureService = context.application.services.activityPubSignatureService
        
        // Validate supported algorithm.
        try activityPubSignatureService.validateAlgorith(on: context, activityPubRequest: payload)
                
        switch payload.activity.type {
        case .delete:
            try await activityPubService.delete(on: context, activityPubRequest: payload)
        case .follow:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.follow(on: context, activity: payload.activity)
        case .accept:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.accept(on: context, activity: payload.activity)
        case .reject:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.reject(on: context, activity: payload.activity)
        case .undo:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.undo(on: context, activity: payload.activity)
        default:
            context.logger.info("Unhandled action type: '\(payload.activity.type)'.")
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubRequestDto) async throws {
        context.logger.error("ActivityPubUserInboxJob error: \(error.localizedDescription). Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').")
    }
}
