//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct PersonDto {
    public let context: ComplexType<ContextDto>
    public let id: String
    public let type: String
    public let following: String?
    public let followers: String?
    public let inbox: String
    public let outbox: String
    public let preferredUsername: String
    public let name: String
    public let summary: String?
    public let url: String
    public let alsoKnownAs: [String]?
    public let manuallyApprovesFollowers: Bool
    public let publicKey: PersonPublicKeyDto
    public let icon: PersonImageDto?
    public let image: PersonImageDto?
    public let endpoints: PersonEndpointsDto
    public let attachment: [PersonAttachmentDto]?
    public let tag: [PersonHashtagDto]?
    
    public init(id: String,
                following: String,
                followers: String,
                inbox: String,
                outbox: String,
                preferredUsername: String,
                name: String,
                summary: String?,
                url: String,
                alsoKnownAs: [String]?,
                manuallyApprovesFollowers: Bool,
                publicKey: PersonPublicKeyDto,
                icon: PersonImageDto?,
                image: PersonImageDto?,
                endpoints: PersonEndpointsDto,
                attachment: [PersonAttachmentDto]?,
                tag: [PersonHashtagDto]?
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
        
        self.type = ActorTypeDto.person.rawValue
        self.id = id
        self.following = following
        self.followers = followers
        self.inbox = inbox
        self.outbox = outbox
        self.preferredUsername = preferredUsername
        self.name = name
        self.summary = summary
        self.url = url
        self.alsoKnownAs = alsoKnownAs
        self.manuallyApprovesFollowers = manuallyApprovesFollowers
        self.publicKey = publicKey
        self.icon = icon
        self.image = image
        self.endpoints = endpoints
        self.attachment = attachment
        self.tag = tag
    }
    
    public init(id: String,
                inbox: String,
                outbox: String,
                preferredUsername: String,
                url: String,
                manuallyApprovesFollowers: Bool,
                endpoints: PersonEndpointsDto,
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
        
        self.type =  ActorTypeDto.application.rawValue
        self.id = id
        self.following = nil
        self.followers = nil
        self.inbox = inbox
        self.outbox = outbox
        self.preferredUsername = preferredUsername
        self.name = ""
        self.summary = nil
        self.url = url
        self.alsoKnownAs = nil
        self.manuallyApprovesFollowers = manuallyApprovesFollowers
        self.publicKey = publicKey
        self.icon = nil
        self.image = nil
        self.endpoints = endpoints
        self.attachment = nil
        self.tag = nil
    }
    
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
        case image
        case endpoints
        case attachment
        case tag
        case alsoKnownAs
    }
}

public extension PersonDto {
    func clearName() -> String {
        guard let tag else {
            return name
        }
        
        var clearName = name
        for item in tag {
            if item.type == .emoji {
                clearName.replace(item.name, with: "")
            }
        }

        return clearName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension PersonDto: Codable {
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.context = try values.decode(ComplexType<ContextDto>.self, forKey: .context)
        self.type = try values.decode(String.self, forKey: .type)
        self.id = try values.decode(String.self, forKey: .id)
        self.following = try values.decodeIfPresent(String.self, forKey: .following)
        self.followers = try values.decodeIfPresent(String.self, forKey: .followers)
        self.inbox = try values.decode(String.self, forKey: .inbox)
        self.outbox = try values.decode(String.self, forKey: .outbox)
        self.preferredUsername = try values.decode(String.self, forKey: .preferredUsername)
        self.name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.summary = try values.decodeIfPresent(String.self, forKey: .summary)
        self.url = try values.decode(String.self, forKey: .url)
        self.alsoKnownAs = try values.decodeIfPresent([String].self, forKey: .alsoKnownAs)
        self.manuallyApprovesFollowers = try values.decodeIfPresent(Bool.self, forKey: .manuallyApprovesFollowers) ?? false
        self.publicKey = try values.decode(PersonPublicKeyDto.self, forKey: .publicKey)
        self.icon = try values.decodeIfPresent(PersonImageDto.self, forKey: .icon)
        self.image = try values.decodeIfPresent(PersonImageDto.self, forKey: .image)
        self.endpoints = try values.decode(PersonEndpointsDto.self, forKey: .endpoints)
        self.attachment = try values.decodeIfPresent([PersonAttachmentDto].self, forKey: .attachment)
        self.tag = try values.decodeIfPresent([PersonHashtagDto].self, forKey: .tag)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(context, forKey: .context)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(following, forKey: .following)
        try container.encodeIfPresent(followers, forKey: .followers)
        try container.encodeIfPresent(inbox, forKey: .inbox)
        try container.encodeIfPresent(outbox, forKey: .outbox)
        try container.encodeIfPresent(preferredUsername, forKey: .preferredUsername)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(alsoKnownAs, forKey: .alsoKnownAs)
        try container.encodeIfPresent(manuallyApprovesFollowers, forKey: .manuallyApprovesFollowers)
        try container.encodeIfPresent(publicKey, forKey: .publicKey)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encodeIfPresent(endpoints, forKey: .endpoints)
        try container.encodeIfPresent(attachment, forKey: .attachment)
        try container.encodeIfPresent(tag, forKey: .tag)
        
        if self.type ==  ActorTypeDto.person.rawValue {
            try container.encodeIfPresent(name, forKey: .name)
        }
    }
}

extension PersonDto: Sendable { }
