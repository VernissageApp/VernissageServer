//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

extension ActivityPubActorsController: RouteCollection {
    
    @_documentation(visibility: private)
    static let uri: PathComponent = .constant("actors")
    
    func boot(routes: RoutesBuilder) throws {
        let activityPubGroup = routes.grouped(ActivityPubActorsController.uri)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubRead))
            .get(":name", use: read)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubInbox))
            .post(":name", "inbox", use: inbox)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubOutbox))
            .post(":name", "outbox", use: outbox)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubFollowing))
            .get(":name", "following", use: following)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubFollowers))
            .get(":name", "followers", use: followers)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.activityPubStatus))
            .get(":name", "statuses", ":id", use: status)
    }
}

/// Controller for support od basic ActivityPub endpoints.
///
/// The controller contains basic methods to operate on the actor in the ActivityPub protocol.
///
/// > Important: Base controller URL: `/api/v1/actors`.
final class ActivityPubActorsController {
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
    ///             "href": "https://example.com/hashtag/Apple",
    ///             "name": "Apple",
    ///             "type": "Hashtag"
    ///         },
    ///         {
    ///             "href": "https://example.com/hashtag/dotNET",
    ///             "name": "dotNET",
    ///             "type": "Hashtag"
    ///         },
    ///         {
    ///             "href": "https://example.com/hashtag/iOS",
    ///             "name": "iOS",
    ///             "type": "Hashtag"
    ///         }
    ///     ],
    ///     "type": "Person",
    ///     "url": "https://example.com/@johndoe"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: The Vapor request to the endpoint.
    ///
    /// - Returns: Information about user information.
    func read(request: Request) async throws -> PersonDto {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let usersService = request.application.services.usersService
        let userFromDb = try await usersService.get(on: request.db, userName: userName)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }
        
        let appplicationSettings = request.application.settings.cached
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        let attachments = try await user.$flexiFields.get(on: request.db)
        let hashtags = try await user.$hashtags.get(on: request.db)
        
        return PersonDto(id: user.activityPubProfile,
                         following: "\(user.activityPubProfile)/following",
                         followers: "\(user.activityPubProfile)/followers",
                         inbox: "\(user.activityPubProfile)/inbox",
                         outbox: "\(user.activityPubProfile)/outbox",
                         preferredUsername: user.userName,
                         name: user.name ?? user.userName,
                         summary: user.bio ?? "",
                         url: "\(baseAddress)/@\(user.userName)",
                         manuallyApprovesFollowers: user.manuallyApprovesFollowers,
                         publicKey: PersonPublicKeyDto(id: "\(user.activityPubProfile)#main-key",
                                                       owner: user.activityPubProfile,
                                                       publicKeyPem: user.publicKey ?? ""),
                         icon: self.getPersonImage(for: user.avatarFileName, on: request),
                         image: self.getPersonImage(for: user.headerFileName, on: request),
                         endpoints: PersonEndpointsDto(sharedInbox: "\(baseAddress)/shared/inbox"),
                         attachment: attachments.map({ PersonAttachmentDto(name: $0.key ?? "", value: $0.value ?? "") }),
                         tag: hashtags.map({ PersonHashtagDto(type: .hashtag, name: $0.hashtag, href: "\(baseAddress)/hashtag/\($0.hashtag)") })
        )
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
        
        // Add user activity into queue.
        let bodyHash = request.body.hash()
        request.logger.info("Activity (type: '\(activityDto.type)', id: '\(activityDto.id)', body hash: '\(bodyHash ?? "")').")
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
        
        // Add user activity into queue.
        let bodyHash = request.body.hash()
        request.logger.info("Activity (type: '\(activityDto.type)', id: '\(activityDto.id)', body hash: '\(bodyHash ?? "")').")
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
    func following(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService
        
        guard let user = try await usersService.get(on: request.db, userName: userName) else {
            throw Abort(.notFound)
        }
        
        let page: String? = request.query["page"]
        
        let userId = try user.requireID()
        let totalItems = try await followsService.count(on: request.db, sourceId: userId)
        
        if let page {
            guard let pageInt = Int(page) else {
                throw Abort(.badRequest)
            }
            
            let following = try await followsService.following(on: request.db, sourceId: userId, onlyApproved: true, page: pageInt, size: orderdCollectionSize)
            let showPrev = pageInt > 1
            let showNext = (pageInt * orderdCollectionSize) < totalItems
            
            return try await OrderedCollectionPageDto(id: "\(user.activityPubProfile)/following?page=\(pageInt)",
                                                      totalItems: totalItems,
                                                      prev: showPrev ? "\(user.activityPubProfile)/following?page=\(pageInt - 1)" : nil,
                                                      next: showNext ? "\(user.activityPubProfile)/following?page=\(pageInt + 1)" : nil,
                                                      partOf: "\(user.activityPubProfile)/following",
                                                      orderedItems: following.items.map({ $0.activityPubProfile })
            )
            .encodeResponse(for: request)
        } else {
            let showFirst = totalItems > 0
            return try await OrderedCollectionDto(id: "\(user.activityPubProfile)/following",
                                                  totalItems: totalItems,
                                                  first: showFirst ? "\(user.activityPubProfile)/following?page=1" : nil)
            .encodeResponse(for: request)
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
    func followers(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService
        
        guard let user = try await usersService.get(on: request.db, userName: userName) else {
            throw Abort(.notFound)
        }
        
        let page: String? = request.query["page"]
        
        let userId = try user.requireID()
        let totalItems = try await followsService.count(on: request.db, targetId: userId)
                
        if let page {
            guard let pageInt = Int(page) else {
                throw Abort(.badRequest)
            }
            
            let follows = try await followsService.follows(on: request.db, targetId: userId, onlyApproved: true, page: pageInt, size: orderdCollectionSize)
            let showPrev = pageInt > 1
            let showNext = (pageInt * orderdCollectionSize) < totalItems

            return try await OrderedCollectionPageDto(id: "\(user.activityPubProfile)/followers?page=\(pageInt)",
                                                      totalItems: totalItems,
                                                      prev: showPrev ? "\(user.activityPubProfile)/followers?page=\(pageInt - 1)" :  nil,
                                                      next: showNext ? "\(user.activityPubProfile)/followers?page=\(pageInt + 1)" : nil,
                                                      partOf: "\(user.activityPubProfile)/followers",
                                                      orderedItems: follows.items.map({ $0.activityPubProfile })
            )
            .encodeResponse(for: request)
        } else {
            let showFirst = totalItems > 0
            return try await OrderedCollectionDto(id: "\(user.activityPubProfile)/followers",
                                                  totalItems: totalItems,
                                                  first: showFirst ? "\(user.activityPubProfile)/followers?page=1" : nil)
            .encodeResponse(for: request)
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
    ///             "href": "https://vernissage.photos/hashtag/blackandwhite",
    ///             "name": "#blackandwhite",
    ///             "type": "Hashtag"
    ///         },
    ///         {
    ///             "href": "https://vernissage.photos/hashtag/streetphotography",
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
    func status(request: Request) async throws -> NoteDto {
        guard let statusId = request.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        
        guard let id = statusId.toId() else {
            throw Abort(.badRequest)
        }

        let statusesService = request.application.services.statusesService
        guard let status = try await statusesService.get(on: request.db, id: id) else {
            throw Abort(.notFound)
        }
        
        guard status.visibility != .mentioned else {
            throw Abort(.forbidden)
        }
        
        guard status.isLocal else {
            throw Abort(.forbidden)
        }
        
        let noteDto = try statusesService.note(basedOn: status, replyToStatus: nil, on: request.application)
        return noteDto
    }
    
    private func getPersonImage(for fileName: String?, on request: Request) -> PersonImageDto? {
        guard let fileName else {
            return nil
        }
        
        let baseStoragePath = request.application.services.storageService.getBaseStoragePath(on: request.application)
        return PersonImageDto(mediaType: "image/jpeg",
                              url: "\(baseStoragePath)/\(fileName)")
    }
}
