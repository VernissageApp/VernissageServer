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

struct ActivityPubFollowResponderJob: AsyncJob {
    typealias Payload = ActivityPubFollowRespondDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubFollowRespondDto) async throws {
        context.logger.info("ActivityPubAcceptJob dequeued job. Accept (requesting: '\(payload.requesting)', asked: '\(payload.asked)').")
        
        let activityPubClient = ActivityPubClient(privatePemKey: payload.privateKey, userAgent: "(Vernissage/1.0.0)", host: payload.sharedInbox.host)
        
        if payload.approved {
            try await activityPubClient.accept(requesting: payload.requesting,
                                               asked: payload.asked,
                                               on: payload.sharedInbox,
                                               withId: payload.id,
                                               orginalRequestId: payload.orginalRequestId)
        } else {
            try await activityPubClient.reject(requesting: payload.requesting,
                                               asked: payload.asked,
                                               on: payload.sharedInbox,
                                               withId: payload.id,
                                               orginalRequestId: payload.orginalRequestId)
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubFollowRespondDto) async throws {
        context.logger.error("ActivityPubAcceptJob error: \(error.localizedDescription). Accept (requesting: '\(payload.requesting)', asked: '\(payload.asked)').")
    }
}
