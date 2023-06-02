//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

final class ActivityPubController: RouteCollection {
    
    public static let uri: PathComponent = .constant("actors")
    
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
    
    func read(request: Request) async throws -> ActorDto {
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
                
        return ActorDto(context: ["https://w3id.org/security/v1", "https://www.w3.org/ns/activitystreams"],
                        id: "\(baseAddress)/actors/\(user.userName)",
                        type: "Person",
                        following: "\(baseAddress)/actors/\(user.userName)/following",
                        followers: "\(baseAddress)/actors/\(user.userName)/followers",
                        inbox: "\(baseAddress)/actors/\(user.userName)/inbox",
                        outbox: "\(baseAddress)/actors/\(user.userName)/outbox",
                        preferredUsername: user.userName,
                        name: user.name ?? user.userName,
                        summary: user.bio ?? "",
                        url: "\(baseAddress)/\(user.userName)",
                        manuallyApprovesFollowers: false,
                        publicKey: ActorPublicKeyDto(id: "\(baseAddress)/actors/\(user.userName)#main-key",
                                                     owner: "\(baseAddress)/actors/\(user.userName)",
                                                     publicKeyPem: user.publicKey),
                        icon: ActorIconDto(type: "Image",
                                           mediaType: "image/jpeg",
                                           url: "https://pixelfed-prod.nyc3.digitaloceanspaces.com/cache/avatars/502420301986951048/avatar_fcyy4.jpg"),
                        endpoints: ActorEndpointsDto(sharedInbox: "\(baseAddress)/f/inbox"))
    }
    
    func inbox(request: Request) async throws -> BooleanResponseDto {
        return BooleanResponseDto(result: true)
    }
    
    func outbox(request: Request) async throws -> BooleanResponseDto {
        return BooleanResponseDto(result: true)
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
        
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        
        if let page {
            guard let pageInt = Int(page) else {
                throw Abort(.badRequest)
            }
            
            let following = try await followsService.following(on: request, sourceId: userId, page: pageInt, size: 10)
            let showPrev = pageInt > 1
            let showNext = pageInt * 10 < totalItems
            
            return try await OrderedCollectionPageDto(id: "\(baseAddress)/actors/\(user.userName)/following?page=\(pageInt)",
                                                      totalItems: totalItems,
                                                      prev: showPrev ? "\(baseAddress)/actors/\(user.userName)/following?page=\(pageInt - 1)" : nil,
                                                      next: showNext ? "\(baseAddress)/actors/\(user.userName)/following?page=\(pageInt + 1)" : nil,
                                                      partOf: "\(baseAddress)/actors/\(user.userName)/following",
                                                      orderedItems: following.items.map({ $0.activityPubProfile })
            )
            .encodeResponse(for: request)
        } else {
            return try await OrderedCollectionDto(id: "\(baseAddress)/actors/\(user.userName)/following",
                                                  totalItems: totalItems,
                                                  first: "\(baseAddress)/actors/\(user.userName)/following?page=1")
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
        
        let appplicationSettings = request.application.settings.get(ApplicationSettings.self)
        let baseAddress = appplicationSettings?.baseAddress ?? ""
        
        if let page {
            guard let pageInt = Int(page) else {
                throw Abort(.badRequest)
            }
            
            let follows = try await followsService.follows(on: request, targetId: userId, page: pageInt, size: 10)
            let showPrev = pageInt > 1
            let showNext = pageInt * 10 < totalItems

            return try await OrderedCollectionPageDto(id: "\(baseAddress)/actors/\(user.userName)/followers?page=\(pageInt)",
                                                      totalItems: totalItems,
                                                      prev: showPrev ? "\(baseAddress)/actors/\(user.userName)/followers?page=\(pageInt - 1)" :  nil,
                                                      next: showNext ? "\(baseAddress)/actors/\(user.userName)/followers?page=\(pageInt + 1)" : nil,
                                                      partOf: "\(baseAddress)/actors/\(user.userName)/followers",
                                                      orderedItems: follows.items.map({ $0.activityPubProfile })
            )
            .encodeResponse(for: request)
        } else {
            return try await OrderedCollectionDto(id: "\(baseAddress)/actors/\(user.userName)/followers",
                                                  totalItems: totalItems,
                                                  first: "\(baseAddress)/actors/\(user.userName)/followers?page=1")
            .encodeResponse(for: request)
        }
    }
    
    func liked(request: Request) async throws -> BooleanResponseDto {
        return BooleanResponseDto(result: true)
    }
}
