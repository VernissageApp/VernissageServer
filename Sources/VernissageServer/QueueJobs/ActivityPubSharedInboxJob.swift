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
        
        // Validate supported algorithm.
        try activityPubSignatureService.validateAlgorith(on: context, activityPubRequest: payload)
        
        switch payload.activity.type {
        case .delete:
            // Signature have to be verified depending on deleting kind of object.
            try await activityPubService.delete(on: context, activityPubRequest: payload)
        case .create:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.create(on: context, activityPubRequest: payload)
        case .follow:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.follow(on: context, activityPubRequest: payload)
        case .accept:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.accept(on: context, activityPubRequest: payload)
        case .reject:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.reject(on: context, activityPubRequest: payload)
        case .undo:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.undo(on: context, activityPubRequest: payload)
        case .announce:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.announce(on: context, activityPubRequest: payload)
        case .like:
            try await activityPubSignatureService.validateSignature(on: context, activityPubRequest: payload)
            try await activityPubService.like(on: context, activityPubRequest: payload)
        default:
            context.logger.info("Unhandled action type: '\(payload.activity.type)'.")
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubRequestDto) async throws {
        await context.logger.store("ActivityPubSharedJob error. Activity (type: '\(payload.activity.type)', id: '\(payload.activity.id)').", error, on: context.application)
    }
}
