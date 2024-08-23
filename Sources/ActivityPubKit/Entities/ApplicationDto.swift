//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct ApplicationDto {
    public let context: ComplexType<ContextDto>
    public let id: String
    public let type = "Application"
    public let inbox: String
    public let outbox: String
    public let preferredUsername: String
    public let url: String
    public let manuallyApprovesFollowers: Bool
    public let endpoints: ApplicationEndpointsDto
    public let publicKey: PersonPublicKeyDto
    
    public init(id: String,
                inbox: String,
                outbox: String,
                preferredUsername: String,
                url: String,
                manuallyApprovesFollowers: Bool,
                endpoints: ApplicationEndpointsDto,
                publicKey: PersonPublicKeyDto
    ) {
        self.context = .multiple([
            ContextDto(value: "https://w3id.org/security/v1"),
            ContextDto(value: "https://www.w3.org/ns/activitystreams"),
            ContextDto(manuallyApprovesFollowers: "as:manuallyApprovesFollowers",
                       toot: "http://joinmastodon.org/ns#",
                       schema: "http://schema.org#",
                       propertyValue: "schema:PropertyValue",
                       alsoKnownAs: AlsoKnownAs(id: "as:alsoKnownAs", type: "@id"))
        ])
        
        self.id = id
        self.inbox = inbox
        self.outbox = outbox
        self.preferredUsername = preferredUsername
        self.url = url
        self.manuallyApprovesFollowers = manuallyApprovesFollowers
        self.endpoints = endpoints
        self.publicKey = publicKey
    }
    
    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case type
        case inbox
        case outbox
        case preferredUsername
        case url
        case manuallyApprovesFollowers
        case endpoints
        case publicKey
    }
}

extension ApplicationDto: Codable { }
