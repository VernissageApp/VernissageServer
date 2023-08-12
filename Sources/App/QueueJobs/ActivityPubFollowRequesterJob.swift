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
 Here we have code responsible for sending follow/unfollow requests to remote instances.
 
 Request URL: `POST /shared/inbox`
 Request body:
 ```json
 {
     "@context":"https:\/\/www.w3.org\/ns\/activitystreams",
     "id":"https:\/\/pxlmo.com\/users\/jfick#follow\/590451308086793127",
     "type":"Follow",
     "actor":"https:\/\/pxlmo.com\/users\/jfick",
     "object":"https:\/\/vernissage.photos\/actors\/mczachurski"
 }
 ```
 
 Request URL: `POST /shared/inbox`
 Request body:
 ```json
 {
     "@context":"https:\/\/www.w3.org\/ns\/activitystreams",
     "id":"https:\/\/pxlmo.com\/users\/jfick#follow\/590451308086793127\/undo",
     "type":"Undo",
     "actor":"https:\/\/pxlmo.com\/users\/jfick",
     "object": {
         "id":"https:\/\/pxlmo.com\/users\/jfick#follows\/590451308086793127",
         "actor":"https:\/\/pxlmo.com\/users\/jfick",
         "object":"https:\/\/vernissage.photos\/actors\/mczachurski",
         "type":"Follow"
     }
 }
 ```
 
 For follow request after sending request we have to expected that we will got `Accept` or `Reject` activity. Activity will be send
 automatically when user disabled manual approval or we have to wait for manual approval.
*/
struct ActivityPubFollowRequesterJob: AsyncJob {
    typealias Payload = ActivityPubFollowRequestDto

    func dequeue(_ context: QueueContext, _ payload: ActivityPubFollowRequestDto) async throws {
        context.logger.info("ActivityPubFollowRequesterJob dequeued job. Entity data (source: '\(payload.source)', target: '\(payload.target)', type: '\(payload.type)').")
        
        let activityPubClient = ActivityPubClient(privatePemKey: payload.privateKey, userAgent: Constants.userAgent, host: payload.sharedInbox.host)
        
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
