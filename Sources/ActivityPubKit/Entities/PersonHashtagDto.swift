//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct PersonHashtagDto {
    public let type: PersonHashtagTypeDto
    public let name: String
    public let href: String?
    public let icon: PersonImageDto?
    
    public init(type: PersonHashtagTypeDto, name: String, href: String? = nil, icon: PersonImageDto? = nil) {
        self.type = type
        self.name = name
        self.href = href
        self.icon = icon
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case name
        case href
        case icon
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try values.decode(PersonHashtagTypeDto.self, forKey: .type)
        self.name = try values.decode(String.self, forKey: .name)
        self.href = try values.decodeIfPresent(String.self, forKey: .href)
        self.icon = try values.decodeIfPresent(PersonImageDto.self, forKey: .icon)
    
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self.type {
        case .hashtag:
            try container.encode(self.type, forKey: .type)
            try container.encode(self.name, forKey: .name)
            try container.encode(self.href, forKey: .href)
        case .emoji:
            try container.encode(self.type, forKey: .type)
            try container.encode(self.name, forKey: .name)
            try container.encode(self.icon, forKey: .icon)
        }
    }
}

extension PersonHashtagDto: Codable { }
extension PersonHashtagDto: Sendable { }
