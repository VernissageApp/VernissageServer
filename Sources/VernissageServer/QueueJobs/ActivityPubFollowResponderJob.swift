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

/**
 Here we have code responsible for sending accept/reject requests to remote instances.
 
 Request URL: `POST /users/jfick/inbox"`
 Request body:
 ```json
 {
     "@context":"https://www.w3.org/ns/activitystreams",
     "id":"https://vernissage.photos/actors/mczachurski#accept/follow/7266320585855688705",
     "type":"Accept",
     "actor":"https://vernissage.photos/actors/mczachurski",
     "object": {
         "id":"https://pxlmo.com/users/jfick#follow/42312",
         "actor":"https://pxlmo.com/users/jfick",
         "type":"Follow",
         "object":"https://vernissage.photos/actors/mczachurski"
     }
 }
 ```
 
 Request URL: `POST /users/jfick/inbox`
 Request body:
 ```json
 {
     "@context":"https://www.w3.org/ns/activitystreams",
     "id":"https://vernissage.photos/actors/mczachurski#accept/follow/7266320585855688705",
     "type":"Reject",
     "actor":"https://vernissage.photos/actors/mczachurski",
     "object": {
         "id":"https://pxlmo.com/users/jfick#follow/42312",
         "actor":"https://pxlmo.com/users/jfick",
         "type":"Follow",
         "object":"https://vernissage.photos/actors/mczachurski"
     }
 }
 ```
 After sending `Accept` request remote instance should start sending information from following account.
*/
struct ActivityPubFollowResponderJob: AsyncJob {
    typealias Payload = ActivityPubFollowRespondDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubFollowRespondDto) async throws {
        context.logger.info("ActivityPubAcceptJob dequeued job. Accept (requesting: '\(payload.requesting)', asked: '\(payload.asked)').")
        
        let activityPubClient = ActivityPubClient(privatePemKey: payload.privateKey, userAgent: Constants.userAgent, host: payload.inbox.host)
        
        if payload.approved {
            try await activityPubClient.accept(requesting: payload.requesting,
                                               asked: payload.asked,
                                               on: payload.inbox,
                                               withId: payload.id,
                                               orginalRequestId: payload.orginalRequestId)
        } else {
            try await activityPubClient.reject(requesting: payload.requesting,
                                               asked: payload.asked,
                                               on: payload.inbox,
                                               withId: payload.id,
                                               orginalRequestId: payload.orginalRequestId)
        }
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: ActivityPubFollowRespondDto) async throws {
        context.logger.error("ActivityPubAcceptJob error: \(error.localizedDescription). Accept (requesting: '\(payload.requesting)', asked: '\(payload.asked)').")
    }
}
