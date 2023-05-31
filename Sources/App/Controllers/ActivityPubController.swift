import Vapor

final class ActivityPubController: RouteCollection {
    
    public static let uri: PathComponent = .constant("apusers")
    
    func boot(routes: RoutesBuilder) throws {
        let activityPubGroup = routes.grouped(ActivityPubController.uri)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.usersRead))
            .get(":name", use: read)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.registerUserName))
            .post(":name", "inbox", use: inbox)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.registerUserName))
            .post(":name", "outbox", use: outbox)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.registerUserName))
            .get(":name", "following", use: following)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.registerUserName))
            .get(":name", "followers", use: followers)
        
        activityPubGroup
            .grouped(EventHandlerMiddleware(.registerUserName))
            .get(":name", "liked", use: liked)
    }
    
    func read(request: Request) async throws -> APUserDto {
        //        let name = req.parameters.get("name")
        //        guard let name else {
        //            throw Abort(.notFound)
        //        }
                
        return APUserDto(context: ["https://w3id.org/security/v1", "https://www.w3.org/ns/activitystreams"],
                         id: "https://vernissage.photos/users/mczachurski",
                         type: "Person",
                         following: "https://vernissage.photos/users/mczachurski/following",
                         followers: "https://vernissage.photos/users/mczachurski/followers",
                         inbox: "https://vernissage.photos/users/mczachurski/inbox",
                         outbox: "https://vernissage.photos/users/mczachurski/outbox",
                         preferredUsername: "mczachurski",
                         name: "Marcin Czachurski",
                         summary: "<a href=\"https://pixelfed.social/discover/tags/iOS?src=hash\" title=\"#iOS\" class=\"u-url hashtag\" rel=\"external nofollow noopener\">#iOS</a>/<a href=\"https://pixelfed.social/discover/tags/dotNET?src=hash\" title=\"#dotNET\" class=\"u-url hashtag\" rel=\"external nofollow noopener\">#dotNET</a> developer, <a href=\"https://pixelfed.social/discover/tags/Apple?src=hash\" title=\"#Apple\" class=\"u-url hashtag\" rel=\"external nofollow noopener\">#Apple</a>  fanboy,  📷 aspiring photographer (digital &amp; 35mm film, mostly black and white)",
                         url: "https://vernissage.photos/mczachurski",
                         manuallyApprovesFollowers: false,
                         publicKey: APUserPublicKeyDto(id: "https://vernissage.photos/users/mczachurski#main-key",
                                                       owner: "https://vernissage.photos/users/mczachurski",
                                                       publicKeyPem: publicPemKey),
                         icon: APUserIconDto(type: "Image",
                                             mediaType: "image/jpeg",
                                             url: "https://pixelfed-prod.nyc3.digitaloceanspaces.com/cache/avatars/502420301986951048/avatar_fcyy4.jpg"),
                         endpoints: APUserEndpointsDto(sharedInbox: "https://vernissage.photos/f/inbox"))
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

struct APUserDto: Content {
    public let context: [String]
    public let id: String
    public let type: String
    public let following: String
    public let followers: String
    public let inbox: String
    public let outbox: String
    public let preferredUsername: String
    public let name: String
    public let summary: String
    public let url: String
    public let manuallyApprovesFollowers: Bool
    public let publicKey: APUserPublicKeyDto
    public let icon: APUserIconDto
    public let endpoints: APUserEndpointsDto
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case following
        case followers
        case inbox
        case outbox
        case preferredUsername
        case name
        case summary
        case url
        case manuallyApprovesFollowers
        case publicKey
        case icon
        case endpoints
    }
}

struct APUserPublicKeyDto: Content {
    public let id: String
    public let owner: String
    public let publicKeyPem: String
}

struct APUserIconDto: Content {
    public let type: String
    public let mediaType: String
    public let url: String
}

struct APUserEndpointsDto: Content {
    public let sharedInbox: String
}
