//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct PersonDto {
    public let context = ["https://w3id.org/security/v1", "https://www.w3.org/ns/activitystreams"]
    public let id: String
    public let type = "Person"
    public let following: String
    public let followers: String
    public let inbox: String
    public let outbox: String
    public let preferredUsername: String
    public let name: String
    public let summary: String?
    public let url: String
    public let manuallyApprovesFollowers: Bool
    public let publicKey: PersonPublicKeyDto
    public let icon: PersonImageDto?
    public let image: PersonImageDto?
    public let endpoints: PersonEndpointsDto
    public let attachment: [PersonAttachmentDto]?
    public let tag: [PersonHashtagDto]?
    public let emojis: [EmojiDto]?
    public let fields: [FieldDto]?
    
    public init(id: String,
                following: String,
                followers: String,
                inbox: String,
                outbox: String,
                preferredUsername: String,
                name: String,
                summary: String?,
                url: String,
                manuallyApprovesFollowers: Bool,
                publicKey: PersonPublicKeyDto,
                icon: PersonImageDto?,
                image: PersonImageDto?,
                endpoints: PersonEndpointsDto,
                attachment: [PersonAttachmentDto]?,
                tag: [PersonHashtagDto]?,
                emojis: [EmojiDto]?,
                fields: [FieldDto]?
    ) {
        self.id = id
        self.following = following
        self.followers = followers
        self.inbox = inbox
        self.outbox = outbox
        self.preferredUsername = preferredUsername
        self.name = name
        self.summary = summary
        self.url = url
        self.manuallyApprovesFollowers = manuallyApprovesFollowers
        self.publicKey = publicKey
        self.icon = icon
        self.image = image
        self.endpoints = endpoints
        self.attachment = attachment
        self.tag = tag
        self.emojis = emojis
        self.fields = fields
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
        case emojis
        case fields
    }
}

public extension PersonDto {
    func clearName() -> String {
        guard let emojis else {
            return name
        }
        
        var clearName = name
        for emoji in emojis {
            if let shortcode = emoji.shortcode {
                clearName.replace(":\(shortcode):", with: "")
            }
        }

        return clearName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension PersonDto: Codable { }
