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
                                                     publicKeyPem: publicPemKey),
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
    
    func following(request: Request) async throws -> BooleanResponseDto {
        return BooleanResponseDto(result: true)
    }
    
    func followers(request: Request) async throws -> BooleanResponseDto {
        return BooleanResponseDto(result: true)
    }
    
    func liked(request: Request) async throws -> BooleanResponseDto {
        return BooleanResponseDto(result: true)
    }
}

let publicPemKey =
"""
-----BEGIN RSA PUBLIC KEY-----
MIIBigKCAYEAluEyQdORtvdBsZy+QbPgbKhXs269Dq2YJo5wH/QCLQeD6UgZBrlr
QFeWGEP8jB1m35Smanr4V9RZjoCCktUpj8J8/RfEceb5gG8I6JqTDu9i7qy65E3n
NZHvjPy1RHaaJG8tH4sTsHpy1SSLEkRUEpNshyGzqSZQ4zIo6whxQhQGRToxP6jl
Yl7cmIPnTh9nuvjbmwPDoxcdrPA24npkCVNDHNCLoMeom3NLym9IvrY9GooyVcAy
WLZzyz9JAbPu5936Ec/oj6H0YGSr1A9Ehmt8C+Ff4qT67umNVDFcYKaU6kxZzQvj
MVZlSdfzYGzMoh1SxNgp+KeICLa8cgT+hVwDhxEE2P7iwhLvsUp+dH3fXq88BfOw
sytDmznAiteSSGXjiwfSSMO2vULT2zmpMblqrjqwRUHikGK/ILcUhbBGw6+cIxsF
QN8U4Box5lkYl3dNtB20a+vDds/wL7NQJLO/q39PxE6+vua+mBL8wY61kz8zMOAp
GZEiQCwinjGhAgMBAAE=
-----END RSA PUBLIC KEY-----
"""
