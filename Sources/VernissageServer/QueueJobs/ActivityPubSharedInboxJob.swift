//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import ActivityPubKit

/// Bakcground job resposible for consumig all request done to Activity Pub shared inbox.
struct ActivityPubSharedInboxJob: AsyncJob {
    typealias Payload = ActivityPubRequestDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubRequestDto) async throws {
        context.logger.info("ActivityPubSharedJob dequeued job. Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').")
        
        let activityPubService = context.application.services.activityPubService
        let activityPubSignatureService = context.application.services.activityPubSignatureService
        let executionContext = context.executionContext
        
        // Validate supported algorithm.
        try activityPubSignatureService.validateAlgorith(activityPubRequest: payload, on: executionContext)
        
        switch payload.activity.type {
        case .delete:
            // Signature have to be verified depending on deleting kind of object.
            try await activityPubService.delete(activityPubRequest: payload, on: executionContext)
        case .create:
            try await activityPubSignatureService.validateSignature(activityPubRequest: payload, on: executionContext)
            try await activityPubService.create(activityPubRequest: payload, on: executionContext)
        case .follow:
            try await activityPubSignatureService.validateSignature(activityPubRequest: payload, on: executionContext)
            try await activityPubService.follow(activityPubRequest: payload, on: executionContext)
        case .accept:
            try await activityPubSignatureService.validateSignature(activityPubRequest: payload, on: executionContext)
            try await activityPubService.accept(activityPubRequest: payload, on: executionContext)
        case .reject:
            try await activityPubSignatureService.validateSignature(activityPubRequest: payload, on: executionContext)
            try await activityPubService.reject(activityPubRequest: payload, on: executionContext)
        case .undo:
            try await activityPubSignatureService.validateSignature(activityPubRequest: payload, on: executionContext)
            try await activityPubService.undo(activityPubRequest: payload, on: executionContext)
        case .announce:
            try await activityPubSignatureService.validateSignature(activityPubRequest: payload, on: executionContext)
            try await activityPubService.announce(activityPubRequest: payload, on: executionContext)
        case .like:
            try await activityPubSignatureService.validateSignature(activityPubRequest: payload, on: executionContext)
            try await activityPubService.like(activityPubRequest: payload, on: executionContext)
        default:
            context.logger.info("Unhandled action type: '\(payload.activity.type)'.")
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubRequestDto) async throws {
        await context.logger.store("ActivityPubSharedJob error. Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').", error, on: context.application)
    }
}
