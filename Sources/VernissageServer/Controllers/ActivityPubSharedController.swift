//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Queues

extension ActivityPubSharedController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("shared")
    
    func boot(routes: RoutesBuilder) throws {
        let activityPubSharedGroup = routes.grouped(ActivityPubSharedController.uri)
        
        activityPubSharedGroup
            .grouped(EventHandlerMiddleware(.activityPubSharedInbox))
            .post("inbox", use: inbox)
    }
}

/// Controller for support shared functionality of ActivityPub.
///
/// A shared inbox refers to a central location where messages, activities, or notifications intended
/// for multiple recipients are collected and distributed. This shared inbox mechanism is crucial for
/// facilitating communication and interaction between actors in a decentralized social networking ecosystem. 
///
/// > Important: Base controller URL: `/shared`.
struct ActivityPubSharedController {

    /// Endpoint for different kind of requests for Activity Pub protocol support.
    ///
    /// > Important: Endpoint URL: `/shared/inbox`.
    ///
    /// **CURL request:**
    /// 
    /// ```bash
    /// curl "https://example.com/shared/inbox" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// **Example request body:**
    ///
    /// ```json
    /// {
    ///     "@context": [
    ///         "https://w3id.org/security/v1",
    ///         "https://www.w3.org/ns/activitystreams",
    ///         {
    ///             "Hashtag": "as:Hashtag",
    ///             "sensitive": "as:sensitive",
    ///             "schema": "http://schema.org/",
    ///             "pixelfed": "http://pixelfed.org/ns#",
    ///             "commentsEnabled": {
    ///                 "@id": "pixelfed:commentsEnabled",
    ///                 "@type": "schema:Boolean"
    ///             },
    ///             "capabilities": {
    ///                 "@id": "pixelfed:capabilities",
    ///                 "@container": "@set"
    ///             },
    ///             "announce": {
    ///                 "@id": "pixelfed:canAnnounce",
    ///                 "@type": "@id"
    ///             },
    ///             "like": {
    ///                 "@id": "pixelfed:canLike",
    ///                 "@type": "@id"
    ///             },
    ///             "reply": {
    ///                 "@id": "pixelfed:canReply",
    ///                 "@type": "@id"
    ///             },
    ///             "toot": "http://joinmastodon.org/ns#",
    ///             "Emoji": "toot:Emoji",
    ///             "blurhash": "toot:blurhash"
    ///         }
    ///     ],
    ///     "id": "https://pixelfed.social/p/mczachurski/650595293594582993/activity",
    ///     "type": "Create",
    ///     "actor": "https://pixelfed.social/users/mczachurski",
    ///     "published": "2024-01-10T07:13:25+00:00",
    ///     "to": [
    ///         "https://www.w3.org/ns/activitystreams#Public"
    ///     ],
    ///     "cc": [
    ///         "https://pixelfed.social/users/mczachurski/followers",
    ///         "https://gram.social/users/Alice"
    ///     ],
    ///     "object": {
    ///         "id": "https://pixelfed.social/p/mczachurski/650595293594582993",
    ///         "type": "Note",
    ///         "summary": null,
    ///         "content": "Extra colours!",
    ///         "inReplyTo": "https://gram.social/p/Alice/650350850687790456",
    ///         "published": "2024-01-10T07:13:25+00:00",
    ///         "url": "https://pixelfed.social/p/mczachurski/650595293594582993",
    ///         "attributedTo": "https://pixelfed.social/users/mczachurski",
    ///         "to": [
    ///             "https://www.w3.org/ns/activitystreams#Public"
    ///         ],
    ///         "cc": [
    ///             "https://pixelfed.social/users/mczachurski/followers",
    ///             "https://gram.social/users/Alice"
    ///         ],
    ///         "sensitive": false,
    ///         "attachment": [],
    ///         "tag": {
    ///             "type": "Mention",
    ///             "href": "https://gram.social/users/Alice",
    ///             "name": "@Alice@gram.social"
    ///         },
    ///         "commentsEnabled": true,
    ///         "capabilities": {
    ///             "announce": "https://www.w3.org/ns/activitystreams#Public",
    ///             "like": "https://www.w3.org/ns/activitystreams#Public",
    ///             "reply": "https://www.w3.org/ns/activitystreams#Public"
    ///         },
    ///         "location": null
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///   
    /// - Returns: HTTP status code.
    @Sendable
    func inbox(request: Request) async throws -> HTTPStatus {
        request.logger.info("\(request.headers.description)")
        if let bodyString = request.body.string {
            request.logger.info("\(bodyString)")
        }
        
        // Deserialize activity from body.
        guard let activityDto = try request.body.activity() else {
            request.logger.warning("Shared inbox activity has not be deserialized.",
                                   metadata: [Constants.requestMetadata: request.body.bodyValue.loggerMetadata()])
            return HTTPStatus.ok
        }
        
        // Skip requests from domains blocked by the instance.
        let activityPubService = request.application.services.activityPubService
        if try await activityPubService.isDomainBlockedByInstance(on: request.application, activity: activityDto) {
            request.logger.info("Activity blocked by instance (type: \(activityDto.type), id: '\(activityDto.id)', activityPubProfile: \(activityDto.actor.actorIds().first ?? "")")
            return HTTPStatus.ok
        }
        
        // Add shared activity into queue.
        let bodyHash = request.body.hash()
        request.logger.info("Activity (type: '\(activityDto.type)', id: '\(activityDto.id)', body hash: '\(bodyHash ?? "")').")
        let headers = request.headers.dictionary()
        let activityPubRequest = ActivityPubRequestDto(activity: activityDto,
                                                       headers: headers,
                                                       bodyHash: bodyHash,
                                                       bodyValue: request.body.bodyValue,
                                                       httpMethod: .post,
                                                       httpPath: .sharedInbox)
        
        // When echo queue driver is used (e.g. during unit tests) we have to execute request immediatelly.
        if let _ = request.application.queues.driver as? EchoQueuesDriver {
            let queue = ActivityPubSharedInboxJob()
            let queueContext = QueueContext(queueName: .apSharedInbox,
                                            configuration: .init(),
                                            application: request.application,
                                            logger: request.logger,
                                            on: request.eventLoop)

            try await queue.dequeue(queueContext, activityPubRequest)
        } else {
            try await request
                .queues(.apSharedInbox)
                .dispatch(ActivityPubSharedInboxJob.self, activityPubRequest)
        }
        
        return HTTPStatus.ok
    }
}
