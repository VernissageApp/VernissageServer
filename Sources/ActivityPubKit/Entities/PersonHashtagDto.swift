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
        let container = try decoder.singleValueContainer()
        do {
            self.name = try container.decode(String.self)
            self.type = .unknown
            self.href = nil
            self.icon = nil
        } catch DecodingError.typeMismatch {
            let personHashtagDataDto = try container.decode(PersonHashtagDataDto.self)
            self.name = personHashtagDataDto.name
            self.type = personHashtagDataDto.type
            self.href = personHashtagDataDto.href
            self.icon = personHashtagDataDto.icon
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self.type {
        case .hashtag:
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.name, forKey: .name)
            try container.encode(self.href, forKey: .href)
        case .emoji:
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.name, forKey: .name)
            try container.encode(self.icon, forKey: .icon)
        case .unknown:
            var container = encoder.singleValueContainer()
            try container.encode(self.href)
        }
    }
}

extension PersonHashtagDto: Equatable {
    public static func == (lhs: PersonHashtagDto, rhs: PersonHashtagDto) -> Bool {
        return lhs.type == rhs.type && lhs.name == rhs.name && lhs.href == rhs.href
    }
}

extension PersonHashtagDto: Codable { }
extension PersonHashtagDto: Sendable { }

fileprivate struct PersonHashtagDataDto {
    public let type: PersonHashtagTypeDto
    public let name: String
    public let href: String?
    public let icon: PersonImageDto?
}

extension PersonHashtagDataDto: Codable { }
