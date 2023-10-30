//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import ActivityPubKit

/// Here we have code resposible for consumig all request done to Activity Pub shared inbox.
struct ActivityPubSharedInboxJob: AsyncJob {
    typealias Payload = ActivityPubRequestDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubRequestDto) async throws {
        context.logger.info("ActivityPubSharedJob dequeued job. Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').")
        
        let activityPubService = context.application.services.activityPubService
        let activityPubSignatureService = context.application.services.activityPubSignatureService
        
        // Validate supported algorithm.
        try activityPubSignatureService.validateAlgorith(on: context, activityPubRequest: payload)
        
        switch payload.activity.type {
        case .delete:
            try activityPubService.delete(on: context, activity: payload.activity)
        case .create:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.create(on: context, activity: payload.activity)
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
        case .announce:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.announce(on: context, activity: payload.activity)
        default:
            context.logger.info("Unhandled action type: '\(payload.activity.type)'.")
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubRequestDto) async throws {
        context.logger.error("ActivityPubSharedJob error: \(error.localizedDescription). Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').")
    }
}
