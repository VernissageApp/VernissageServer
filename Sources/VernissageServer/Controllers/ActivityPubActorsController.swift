//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension ActivityPubActorsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("actors")
    
    func boot(routes: RoutesBuilder) throws {
        let activityPubGroup = routes.grouped(ActivityPubActorsController.uri)
        let statusesGroup = routes.grouped(StatusesController.uri)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubRead))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":name", use: read)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubInbox))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":name", "inbox", use: inbox)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubOutbox))
            .grouped(CacheControlMiddleware(.noStore))
            .post(":name", "outbox", use: outbox)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubFollowing))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":name", "following", use: following)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubFollowers))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":name", "followers", use: followers)
        
        // Support for: https://example.com/actors/@johndoe/statuses/:id
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubStatus))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":name", "statuses", ":id", use: status)

        // Support for: https://example.com/@johndoe/7418207405583904769.
        routes
            .grouped(EventHandlerMiddleware(.activityPubStatus))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":name", ":id", use: status)
        
        // Support for: https://example.com/statuses/:id
        statusesGroup
            .grouped(EventHandlerMiddleware(.activityPubStatus))
            .grouped(CacheControlMiddleware(.noStore))
            .get(":id", use: status)
    }
}

/// Controller for support od basic ActivityPub endpoints.
///
/// The controller contains basic methods to operate on the actor in the ActivityPub protocol.
///
/// > Important: Base controller URL: `/api/v1/actors`.
struct ActivityPubActorsController {
    private let orderdCollectionSize = 10
    
    /// Returns user ActivityPub profile.
    ///
    /// Endpoint for download Activity Pub actor's data. One of the property is public key which should be used to validate requests
    /// done (and signed by private key) by the user in all Activity Pub protocol methods.
    ///
    /// > Important: Endpoint URL: `/api/v1/actors`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/actors/johndoe" \
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
    ///     "attachment": [
    ///         {
    ///             "name": "MASTODON",
    ///             "type": "PropertyValue",
    ///             "value": "https://mastodon.social/@johndoe"
    ///         },
    ///         {
    ///             "name": "GITHUB",
    ///             "type": "PropertyValue",
    ///             "value": "https://github.com/johndoe"
    ///         }
    ///     ],
    ///     "endpoints": {
    ///         "sharedInbox": "https://example.com/shared/inbox"
    ///     },
    ///     "followers": "https://example.com/actors/johndoe/followers",
    ///     "following": "https://example.com/actors/johndoe/following",
    ///     "icon": {
    ///         "mediaType": "image/jpeg",
    ///         "type": "Image",
    ///         "url": "https://s3.eu-central-1.amazonaws.com/instance/039ebf33d1664d5d849574d0e7191354.jpg"
    ///     },
    ///     "id": "https://example.com/actors/johndoe",
    ///     "image": {
    ///         "mediaType": "image/jpeg",
    ///         "type": "Image",
    ///         "url": "https://s3.eu-central-1.amazonaws.com/instance/2ef4a0f69d0e410ba002df2212e2b63c.jpg"
    ///     },
    ///     "inbox": "https://example.com/actors/johndoe/inbox",
    ///     "manuallyApprovesFollowers": false,
    ///     "name": "John Doe",
    ///     "outbox": "https://example.com/actors/johndoe/outbox",
    ///     "preferredUsername": "johndoe",
    ///     "publicKey": {
    ///         "id": "https://example.com/actors/johndoe#main-key",
    ///         "owner": "https://example.com/actors/johndoe",
    ///         "publicKeyPem": "-----BEGIN PUBLIC KEY-----\nM0Q....AB\n-----END PUBLIC KEY-----"
    ///     },
    ///     "summary": "#iOS/#dotNET developer, #Apple  fanboy, 📷 aspiring photographer",
    ///     "tag": [
    ///         {
    ///             "href": "https://example.com/tags/Apple",
    ///             "name": "Apple",
    ///             "type": "Hashtag"
    ///         },
    ///         {
    ///             "href": "https://example.com/tags/dotNET",
    ///             "name": "dotNET",
    ///             "type": "Hashtag"
    ///         },
    ///         {
    ///             "href": "https://example.com/tags/iOS",
    ///             "name": "iOS",
    ///             "type": "Hashtag"
    ///         }
    ///     ],
    ///     "type": "Person",
    ///     "url": "https://example.com/@johndoe",
    ///     "alsoKnownAs": [
    ///         "https://test.social/users/marcin"
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about user information.
    @Sendable
    func read(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let usersService = request.application.services.usersService
        let clearedUserName = userName.deletingPrefix("@")
        let userFromDb = try await usersService.get(userName: clearedUserName, on: request.db)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }
        
        let personDto = try await usersService.getPersonDto(for: user, on: request.executionContext)
        return try await personDto.encodeActivityResponse(for: request)
    }
        
    /// User ActivityPub inbox.
    ///
    /// In the ActivityPub protocol, the actor's inbox serves as a crucial component for enabling communication
    /// and interaction between actors within the decentralized social networking ecosystem. The inbox is essentially
    /// a location where other actors can send messages, notifications, or activities directly to a specific actor.
    ///
    /// > Important: Endpoint URL: `/api/v1/actors/:userName/inbox`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/actors/johndoe/inbox" \
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
        
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
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
            request.logger.info("Activity blocked by instance (type: \(activityDto.type), user: '\(userName)', id: '\(activityDto.id)', activityPubProfile: \(activityDto.actor.actorIds().first ?? "")")
            return HTTPStatus.ok
        }
        
        // Add user activity into queue.
        let bodyHash = request.body.hash()
        request.logger.info("User inbox activity (type: '\(activityDto.type)', user: '\(userName)', id: '\(activityDto.id)', body hash: '\(bodyHash ?? "")').")
        let headers = request.headers.dictionary()
        let activityPubRequest = ActivityPubRequestDto(activity: activityDto,
                                                       headers: headers,
                                                       bodyHash: bodyHash,
                                                       bodyValue: request.body.bodyValue,
                                                       httpMethod: .post,
                                                       httpPath: .userInbox(userName))

        try await request
            .queues(.apUserInbox)
            .dispatch(ActivityPubUserInboxJob.self, activityPubRequest)
        
        return HTTPStatus.ok
    }
    
    /// User ActivityPub outbox,
    ///
    /// In the ActivityPub protocol, the actor outbox serves as a central feature for enabling actors to publish
    /// their activities and share content with other actors in the decentralized social networking ecosystem.
    /// The outbox is essentially a location where an actor's activities are stored and made accessible to other actors.
    ///
    /// > Important: Endpoint URL: `/api/v1/actors/:userName/outbox`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/actors/johndoe/outbox" \
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
        
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
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
            request.logger.info("Activity blocked by instance (type: \(activityDto.type), user: '\(userName)', id: '\(activityDto.id)', activityPubProfile: \(activityDto.actor.actorIds().first ?? "")")
            return HTTPStatus.ok
        }
        
        // Add user activity into queue.
        let bodyHash = request.body.hash()
        request.logger.info("User outbox activity (type: '\(activityDto.type)', user: '\(userName)', id: '\(activityDto.id)', body hash: '\(bodyHash ?? "")').")
        let headers = request.headers.dictionary()
        let activityPubRequest = ActivityPubRequestDto(activity: activityDto,
                                                       headers: headers,
                                                       bodyHash: bodyHash,
                                                       bodyValue: request.body.bodyValue,
                                                       httpMethod: .post,
                                                       httpPath: .userOutbox(userName))
        
        try await request
            .queues(.apUserOutbox)
            .dispatch(ActivityPubUserOutboxJob.self, activityPubRequest)

        return HTTPStatus.ok
    }
    
    /// List of users that are followed by the user.
    ///
    /// In the ActivityPub protocol, the actor following endpoint serves as a means for actors to manage their social
    /// connections and relationships within the decentralized social networking ecosystem. This endpoint allows actors to view,
    /// add, remove, and interact with the list of other actors they are following.
    ///
    /// > Important: Endpoint URL: `/api/v1/actors/:userName/following`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/actors/johndoe/following" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/actors/johndoe/following?page=1" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body without page (200 OK):**
    ///
    /// ```json
    /// {
    ///     "@context": "https://www.w3.org/ns/activitystreams",
    ///     "first": "https://vernissage.photos/actors/mczachurski/following?page=1",
    ///     "id": "https://vernissage.photos/actors/mczachurski/following",
    ///     "totalItems": 8,
    ///     "type": "OrderedCollection"
    /// }
    /// ```
    ///
    /// **Example response body with page (200 OK):**
    ///
    /// ```json
    /// {
    ///     "@context": "https://www.w3.org/ns/activitystreams",
    ///     "id": "https://vernissage.photos/actors/mczachurski/following?page=1",
    ///     "orderedItems": [
    ///         "https://pixelfed.social/users/AlanC",
    ///         "https://pixelfed.social/users/moyamoyashashin",
    ///         "https://vernissage.photos/actors/pczachurski",
    ///         "https://pixelfed.social/users/mczachurski",
    ///         "https://pixelfed.social/users/Devrin",
    ///         "https://vernissage.photos/actors/jlara",
    ///         "https://mastodon.social/users/mczachurski",
    ///         "https://pxlmo.com/users/jfick"
    ///     ],
    ///     "partOf": "https://vernissage.photos/actors/mczachurski/following",
    ///     "totalItems": 8,
    ///     "type": "OrderedCollectionPage"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: [OrderedCollection](https://www.w3.org/TR/activitystreams-vocabulary/#dfn-orderedcollection) when `page` query is not specified
    /// or [OrderedCollectionPage](https://www.w3.org/TR/activitystreams-vocabulary/#dfn-orderedcollectionpage) when `page` is specified.
    @Sendable
    func following(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService
        
        guard let user = try await usersService.get(userName: userName, on: request.db) else {
            throw Abort(.notFound)
        }
        
        let page: String? = request.query["page"]
        
        let userId = try user.requireID()
        let totalItems = try await followsService.count(sourceId: userId, on: request.db)
        
        if let page {
            guard let pageInt = Int(page) else {
                throw Abort(.badRequest)
            }
            
            let following = try await followsService.following(sourceId: userId,
                                                               onlyApproved: true,
                                                               page: pageInt,
                                                               size: orderdCollectionSize,
                                                               on: request.db)

            let showPrev = pageInt > 1
            let showNext = (pageInt * orderdCollectionSize) < totalItems
            
            let orderedCollectionPageDto =  OrderedCollectionPageDto(id: "\(user.activityPubProfile)/following?page=\(pageInt)",
                                                      totalItems: totalItems,
                                                      prev: showPrev ? "\(user.activityPubProfile)/following?page=\(pageInt - 1)" : nil,
                                                      next: showNext ? "\(user.activityPubProfile)/following?page=\(pageInt + 1)" : nil,
                                                      partOf: "\(user.activityPubProfile)/following",
                                                      orderedItems: following.items.map({ $0.activityPubProfile })
            )
            
            return try await orderedCollectionPageDto.encodeActivityResponse(for: request)
        } else {
            let showFirst = totalItems > 0
            let orderedCollectionDto =  OrderedCollectionDto(id: "\(user.activityPubProfile)/following",
                                                  totalItems: totalItems,
                                                  first: showFirst ? "\(user.activityPubProfile)/following?page=1" : nil)
            
            return try await orderedCollectionDto.encodeActivityResponse(for: request)
        }
    }
    
    /// List of users that follow the user.
    ///
    /// In the ActivityPub protocol, the actor followers endpoint serves as a means for actors to retrieve
    /// information about other actors who are following them within the decentralized social networking ecosystem.
    /// This endpoint allows actors to view a list of actors who have subscribed to their activities and updates.
    ///
    /// > Important: Endpoint URL: `/api/v1/actors/:userName/followers`.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/actors/johndoe/followers" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/actors/johndoe/followers?page=1" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body without page (200 OK):**
    ///
    /// ```json
    /// {
    ///     "@context": "https://www.w3.org/ns/activitystreams",
    ///     "first": "https://vernissage.photos/actors/mczachurski/followers?page=1",
    ///     "id": "https://vernissage.photos/actors/mczachurski/followers",
    ///     "totalItems": 6,
    ///     "type": "OrderedCollection"
    /// }
    /// ```
    ///
    /// **Example response body with page (200 OK):**
    ///
    /// ```json
    /// {
    ///     "@context": "https://www.w3.org/ns/activitystreams",
    ///     "id": "https://vernissage.photos/actors/mczachurski/followers?page=1",
    ///     "orderedItems": [
    ///         "https://vernissage.photos/actors/pczachurski",
    ///         "https://pixelfed.social/users/Devrin",
    ///         "https://vernissage.photos/actors/jlara",
    ///         "https://mastodon.social/users/mczachurski",
    ///         "https://pxlmo.com/users/amiko",
    ///         "https://pxlmo.com/users/jfick"
    ///     ],
    ///     "partOf": "https://vernissage.photos/actors/mczachurski/followers",
    ///     "totalItems": 6,
    ///     "type": "OrderedCollectionPage"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: [OrderedCollection](https://www.w3.org/TR/activitystreams-vocabulary/#dfn-orderedcollection) when `page` query is not specified
    /// or [OrderedCollectionPage](https://www.w3.org/TR/activitystreams-vocabulary/#dfn-orderedcollectionpage) when `page` is specified.
    @Sendable
    func followers(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService
        
        guard let user = try await usersService.get(userName: userName, on: request.db) else {
            throw Abort(.notFound)
        }
        
        let page: String? = request.query["page"]
        
        let userId = try user.requireID()
        let totalItems = try await followsService.count(targetId: userId, on: request.db)
                
        if let page {
            guard let pageInt = Int(page) else {
                throw Abort(.badRequest)
            }
            
            let follows = try await followsService.follows(targetId: userId,
                                                           onlyApproved: true,
                                                           page: pageInt,
                                                           size: orderdCollectionSize,
                                                           on: request.db)

            let showPrev = pageInt > 1
            let showNext = (pageInt * orderdCollectionSize) < totalItems

            let orderedCollectionPageDto = OrderedCollectionPageDto(id: "\(user.activityPubProfile)/followers?page=\(pageInt)",
                                                                    totalItems: totalItems,
                                                                    prev: showPrev ? "\(user.activityPubProfile)/followers?page=\(pageInt - 1)" :  nil,
                                                                    next: showNext ? "\(user.activityPubProfile)/followers?page=\(pageInt + 1)" : nil,
                                                                    partOf: "\(user.activityPubProfile)/followers",
                                                                    orderedItems: follows.items.map({ $0.activityPubProfile })
            )
            
            return try await orderedCollectionPageDto.encodeActivityResponse(for: request)
        } else {
            let showFirst = totalItems > 0
            let orderedCollectionDto = OrderedCollectionDto(id: "\(user.activityPubProfile)/followers",
                                                            totalItems: totalItems,
                                                            first: showFirst ? "\(user.activityPubProfile)/followers?page=1" : nil)
            
            return try await orderedCollectionDto.encodeActivityResponse(for: request)
        }
    }
    
    /// Returns user ActivityPub profile.
    ///
    /// **CURL request:**
    ///
    /// ```bash
    /// curl "https://example.com/api/v1/actors/johndoe/statuses/7296951248933498881" \
    /// -X GET \
    /// -H "Content-Type: application/json"
    /// ```
    ///
    /// **Example response body:**
    ///
    /// ```json
    /// {
    ///     "@context": [
    ///         "https://www.w3.org/ns/activitystreams"
    ///     ],
    ///     "attachment": [
    ///         {
    ///             "blurhash": "UGMtaO?b_3%M00Rj_3Rj~qD%IUM{j[ofD%-;",
    ///             "exif": {
    ///                 "createDate": "2022-05-27T11:36:07+01:00",
    ///                 "exposureTime": "1/50",
    ///                 "fNumber": "f/8",
    ///                 "focalLenIn35mmFilm": "85",
    ///                 "lens": "Viltrox 85mm F1.8",
    ///                 "make": "SONY",
    ///                 "model": "ILCE-7M3",
    ///                 "photographicSensitivity": "100"
    ///             },
    ///             "height": 2731,
    ///             "location": {
    ///                 "countryCode": "PL",
    ///                 "countryName": "Poland",
    ///                 "geonameId": "3081368",
    ///                 "latitude": "51,1",
    ///                 "longitude": "17,03333",
    ///                 "name": "Wrocław"
    ///             },
    ///             "mediaType": "image/jpeg",
    ///             "name": "Feet visible from underneath through white foggy glass.",
    ///             "type": "Image",
    ///             "url": "https://s3.eu-central-1.amazonaws.com/vernissage/f154e5d151e441b18d61389f87cc877c.jpg",
    ///             "width": 4096
    ///         }
    ///     ],
    ///     "attributedTo": "https://vernissage.photos/actors/mczachurski",
    ///     "cc": [
    ///         "https://vernissage.photos/actors/mczachurski/followers"
    ///     ],
    ///     "content": "<p>Feet over the head <a href=\"https://vernissage.photos/tags/blackandwhite\">#blackandwhite</a> <a href=\"https://vernissage.photos/tags/streetphotography\">#streetphotography</a></p>",
    ///     "id": "https://vernissage.photos/actors/mczachurski/statuses/7296951248933498881",
    ///     "published": "2023-11-02T19:39:56.303Z",
    ///     "sensitive": false,
    ///     "tag": [
    ///         {
    ///             "href": "https://vernissage.photos/tags/blackandwhite",
    ///             "name": "#blackandwhite",
    ///             "type": "Hashtag"
    ///         },
    ///         {
    ///             "href": "https://vernissage.photos/tags/streetphotography",
    ///             "name": "#streetphotography",
    ///             "type": "Hashtag"
    ///         }
    ///     ],
    ///     "to": [
    ///         "https://www.w3.org/ns/activitystreams#Public"
    ///     ],
    ///     "type": "Note",
    ///     "url": "https://vernissage.photos/@mczachurski/7296951248933498881"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Status data.
    @Sendable
    func status(request: Request) async throws -> Response {
        guard let statusId = request.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        
        guard let id = statusId.toId() else {
            throw Abort(.badRequest)
        }

        let statusesService = request.application.services.statusesService
        guard let status = try await statusesService.get(id: id, on: request.db) else {
            throw Abort(.notFound)
        }
        
        guard status.visibility != .mentioned else {
            throw Abort(.forbidden)
        }
        
        guard status.isLocal else {
            return request.redirect(to: status.activityPubUrl, redirectType: .temporary)
        }
        
        var replyToStatus: Status? = nil
        if let replyToStatusId = status.$replyToStatus.id {
            replyToStatus = try await statusesService.get(id: replyToStatusId, on: request.db)
        }
        
        let noteDto = try await statusesService.note(basedOn: status, replyToStatus: replyToStatus, on: request.executionContext)
        return try await noteDto.encodeActivityResponse(for: request)
    }
}
