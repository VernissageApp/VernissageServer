//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ActorDto: Content {
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
    public let publicKey: ActorPublicKeyDto
    public let icon: ActorIconDto
    public let endpoints: ActorEndpointsDto
    
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
