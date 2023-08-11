//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Foundation
import Queues
import Smtp
import ActivityPubKit

struct ActivityPubFollowRequesterJob: AsyncJob {
    typealias Payload = ActivityPubFollowRequestDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubFollowRequestDto) async throws {
        context.logger.info("ActivityPubFollowRequesterJob dequeued job. Entity data (source: '\(payload.source)', target: '\(payload.target)', type: '\(payload.type)').")
        
        let activityPubClient = ActivityPubClient(privatePemKey: payload.privateKey, userAgent: "(Vernissage/1.0.0)", host: payload.sharedInbox.host)
        
        switch payload.type {
        case .follow:
            try await activityPubClient.follow(payload.target, by: payload.source, on: payload.sharedInbox, withId: payload.id)
        case .unfollow:
            try await activityPubClient.unfollow(payload.target, by: payload.source, on: payload.sharedInbox, withId: payload.id)
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubFollowRequestDto) async throws {
        context.logger.error("ActivityPubFollowRequesterJob error: \(error.localizedDescription). Entity data (source: '\(payload.source)', target: '\(payload.target)', type: '\(payload.type)'.")
    }
}
