//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct PersonDto: Content {
    public let context = ["https://w3id.org/security/v1", "https://www.w3.org/ns/activitystreams"]
    public let id: String
    public let type = "Person"
    public let following: String
    public let followers: String
    public let inbox: String
    public let outbox: String
    public let preferredUsername: String
    public let name: String
    public let summary: String
    public let url: String
    public let manuallyApprovesFollowers: Bool
    public let publicKey: PersonPublicKeyDto
    public let icon: PersonIconDto
    public let endpoints: PersonEndpointsDto
    
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
