//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import Fluent
import ActivityPubKit

extension ActivityPubActorController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("actor")
    
    func boot(routes: RoutesBuilder) throws {
        let actorGroup = routes
            .grouped(ActivityPubActorController.uri)
        
        actorGroup
            .grouped(EventHandlerMiddleware(.actorRead))
            .get(use: read)
        
        actorGroup
            .grouped(EventHandlerMiddleware(.activityPubInbox))
            .post("inbox", use: inbox)
        
        actorGroup
            .grouped(EventHandlerMiddleware(.activityPubOutbox))
            .post("outbox", use: outbox)
    }
}

/// Exposing main application actor.
///
/// > Important: Base controller URL: `/actor`.
struct ActivityPubActorController {
    
    /// Endpint is returning main application actor.
    ///
    /// > Important: Endpoint URL: `/actor`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/actor" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "@context": [
    ///         "https://w3id.org/security/v1",
    ///         "https://www.w3.org/ns/activitystreams"
    ///     ],
    ///     "endpoints": {
    ///         "sharedInbox": "https://example.com/shared/inbox"
    ///     },
    ///     "id": "https://example.com/actor",
    ///     "inbox": "https://example.com/actor/inbox",
    ///     "manuallyApprovesFollowers": false,
    ///     "outbox": "https://example.com/actor/outbox",
    ///     "preferredUsername": "example.com",
    ///     "publicKey": {
    ///         "id": "https://example.com/actors/johndoe#main-key",
    ///         "owner": "https://example.com/actors/johndoe",
    ///         "publicKeyPem": "-----BEGIN PUBLIC KEY-----\nM0Q....AB\n-----END PUBLIC KEY-----"
    ///     },
    ///     "type": "Application",
    ///     "url": "https://example.com/support"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Main instance actor data.
    @Sendable
    func read(request: Request) async throws -> Response {
        let usersService = request.application.services.usersService
        let userFromDb = try await usersService.getDefaultSystemUser(on: request.db)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }
        
        let appplicationSettings = request.application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let domain = appplicationSettings?.domain ?? ""
        
        let applicationDto = PersonDto(id: "\(baseAddress)/actor",
                                       inbox: "\(baseAddress)/actor/inbox",
                                       outbox: "\(baseAddress)/actor/outbox",
                                       preferredUsername: domain,
                                       url: "\(baseAddress)/support",
                                       manuallyApprovesFollowers: true,
                                       endpoints: PersonEndpointsDto(sharedInbox: "\(baseAddress)/shared/inbox"),
                                       publicKey: PersonPublicKeyDto(id: "\(baseAddress)/actor#main-key",
                                                                     owner: "\(baseAddress)/actor",
                                                                     publicKeyPem: user.publicKey ?? "")
        )
        
        return try await applicationDto.encodeActivityResponse(for: request)
    }
    
    /// Application user ActivityPub inbox.
    ///
    /// In the ActivityPub protocol, the actor's inbox serves as a crucial component for enabling communication
    /// and interaction between actors within the decentralized social networking ecosystem. The inbox is essentially
    /// a location where other actors can send messages, notifications, or activities directly to a specific actor.
    ///
    /// > Important: Endpoint URL: `/actor/inbox`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/actor/inbox" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
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
            request.logger.warning("User inbox activity has not be deserialized.",
                                   metadata: [Constants.requestMetadata: request.body.bodyValue.loggerMetadata()])
            return HTTPStatus.ok
        }
        
        // Skip requests from domains blocked by the instance.
        let activityPubService = request.application.services.activityPubService
        if try await activityPubService.isDomainBlockedByInstance(activity: activityDto, on: request.executionContext) {
            request.logger.info("Activity blocked by instance (type: \(activityDto.type), id: '\(activityDto.id)', activityPubProfile: \(activityDto.actor.actorIds().first ?? "")")
            return HTTPStatus.ok
        }
        
        // Add user activity into queue.
        let bodyHash = request.body.hash()
        request.logger.info("Application user inbox activity (type: '\(activityDto.type)', id: '\(activityDto.id)', body hash: '\(bodyHash ?? "")').")
        let headers = request.headers.dictionary()
        let activityPubRequest = ActivityPubRequestDto(activity: activityDto,
                                                       headers: headers,
                                                       bodyHash: bodyHash,
                                                       bodyValue: request.body.bodyValue,
                                                       httpMethod: .post,
                                                       httpPath: .applicationUserInbox)

        try await request
            .queues(.apUserInbox)
            .dispatch(ActivityPubUserInboxJob.self, activityPubRequest)
        
        return HTTPStatus.ok
    }
    
    /// Application user ActivityPub outbox,
    ///
    /// In the ActivityPub protocol, the actor outbox serves as a central feature for enabling actors to publish
    /// their activities and share content with other actors in the decentralized social networking ecosystem.
    /// The outbox is essentially a location where an actor's activities are stored and made accessible to other actors.
    ///
    /// > Important: Endpoint URL: `/actor/outbox`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/actor/outbox" \
    /// -X POST \
    /// -H "Content-Type: application/json" \
    /// -d '{ ... }'
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: HTTP status code.
    @Sendable
    func outbox(request: Request) async throws -> HTTPStatus {
        request.logger.info("\(request.headers.description)")
        if let bodyString = request.body.string {
            request.logger.info("\(bodyString)")
        }
                
        // Deserialize activity from body.
        guard let activityDto = try request.body.activity() else {
            request.logger.warning("User outbox activity has not be deserialized.",
                                   metadata: [Constants.requestMetadata: request.body.bodyValue.loggerMetadata()])
            return HTTPStatus.ok
        }
        
        // Skip requests from domains blocked by the instance.
        let activityPubService = request.application.services.activityPubService
        if try await activityPubService.isDomainBlockedByInstance(activity: activityDto, on: request.executionContext) {
            request.logger.info("Activity blocked by instance (type: \(activityDto.type), id: '\(activityDto.id)', activityPubProfile: \(activityDto.actor.actorIds().first ?? "")")
            return HTTPStatus.ok
        }
        
        // Add user activity into queue.
        let bodyHash = request.body.hash()
        request.logger.info("Application user outbox activity (type: '\(activityDto.type)', id: '\(activityDto.id)', body hash: '\(bodyHash ?? "")').")
        let headers = request.headers.dictionary()
        let activityPubRequest = ActivityPubRequestDto(activity: activityDto,
                                                       headers: headers,
                                                       bodyHash: bodyHash,
                                                       bodyValue: request.body.bodyValue,
                                                       httpMethod: .post,
                                                       httpPath: .applicationUserOutbox)
        
        try await request
            .queues(.apUserOutbox)
            .dispatch(ActivityPubUserOutboxJob.self, activityPubRequest)

        return HTTPStatus.ok
    }
}
