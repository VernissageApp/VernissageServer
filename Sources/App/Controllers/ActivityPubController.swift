//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor
import ActivityPubKit

final class ActivityPubController: RouteCollection {
    
    public static let uri: PathComponent = .constant("actors")
    private let orderdCollectionSize = 10
    
    func boot(routes: RoutesBuilder) throws {
        let activityPubGroup = routes.grouped(ActivityPubController.uri)
        
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
            .grouped(EventHandlerMiddleware(.activityPubLiked))
            .get(":name", "liked", use: liked)
    }
    
    func read(request: Request) async throws -> PersonDto {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }

        let usersService = request.application.services.usersService
        let userFromDb = try await usersService.get(on: request, userName: userName)
        
        guard let user = userFromDb else {
            throw EntityNotFoundError.userNotFound
        }
        
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        let baseAddress = appplicationSettings?.baseAddress ?? ""
                
        return PersonDto(id: user.activityPubProfile,
                         following: "\(user.activityPubProfile)/following",
                         followers: "\(user.activityPubProfile)/followers",
                         inbox: "\(user.activityPubProfile)/inbox",
                         outbox: "\(user.activityPubProfile)/outbox",
                         preferredUsername: user.userName,
                         name: user.name ?? user.userName,
                         summary: user.bio ?? "",
                         url: "\(baseAddress)/\(user.userName)",
                         manuallyApprovesFollowers: user.manuallyApprovesFollowers,
                         publicKey: PersonPublicKeyDto(id: "\(user.activityPubProfile)#main-key",
                                                       owner: user.activityPubProfile,
                                                       publicKeyPem: user.publicKey ?? ""),
                         icon: PersonIconDto(type: "Image",
                                             mediaType: "image/jpeg",
                                             url: "https://pixelfed-prod.nyc3.digitaloceanspaces.com/cache/avatars/502420301986951048/avatar_fcyy4.jpg"),
                         endpoints: PersonEndpointsDto(sharedInbox: "\(baseAddress)/shared/inbox"))
    }
        
    func inbox(request: Request) async throws -> HTTPStatus {
        if let bodyString = request.body.string {
            request.logger.info("\(bodyString)")
        }

        // Deserialize activity from body.
        guard let activityDto = try request.body.activity() else {
            request.logger.warning("User inbox activity has not be deserialized.")
            return HTTPStatus.ok
        }
        
        // Add user activity into queue.
        request.logger.info("Activity (type: '\(activityDto.type)', id: '\(activityDto.id)').")
        try await request.queue.dispatch(ActivityPubUserInboxJob.self, activityDto)
        
        return HTTPStatus.ok
    }
    
    func outbox(request: Request) async throws -> HTTPStatus {
        if let bodyString = request.body.string {
            request.logger.info("\(bodyString)")
        }
        
        // Deserialize activity from body.
        guard let activityDto = try request.body.activity() else {
            request.logger.warning("User outbox activity has not be deserialized.")
            return HTTPStatus.ok
        }
        
        // Add user activity into queue.
        request.logger.info("Activity (type: '\(activityDto.type)', id: '\(activityDto.id)').")
        try await request.queue.dispatch(ActivityPubUserOutboxJob.self, activityDto)

        return HTTPStatus.ok
    }
    
    func following(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService
        
        guard let user = try await usersService.get(on: request, userName: userName) else {
            throw Abort(.notFound)
        }
        
        let page: String? = request.query["page"]
        
        let userId = try user.requireID()
        let totalItems = try await followsService.count(on: request, sourceId: userId)
        
        if let page {
            guard let pageInt = Int(page) else {
                throw Abort(.badRequest)
            }
            
            let following = try await followsService.following(on: request, sourceId: userId, page: pageInt, size: orderdCollectionSize)
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
    
    func followers(request: Request) async throws -> Response {
        guard let userName = request.parameters.get("name") else {
            throw Abort(.badRequest)
        }
        
        let usersService = request.application.services.usersService
        let followsService = request.application.services.followsService
        
        guard let user = try await usersService.get(on: request, userName: userName) else {
            throw Abort(.notFound)
        }
        
        let page: String? = request.query["page"]
        
        let userId = try user.requireID()
        let totalItems = try await followsService.count(on: request, targetId: userId)
                
        if let page {
            guard let pageInt = Int(page) else {
                throw Abort(.badRequest)
            }
            
            let follows = try await followsService.follows(on: request, targetId: userId, page: pageInt, size: orderdCollectionSize)
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
    
    func liked(request: Request) async throws -> BooleanResponseDto {
        return BooleanResponseDto(result: true)
    }
}
