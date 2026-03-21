//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct UrlDto {
    public let href: String
    public let type: UrlTypeDto?
    public let rel: String?
    
    enum CodingKeys: String, CodingKey {
        case href
        case type
        case rel
    }
    
    public init(href: String, type: UrlTypeDto? = nil, rel: String? = nil) {
        self.href = href
        self.type = type
        self.rel = rel
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self.href = try container.decode(String.self)
            self.rel = nil
            self.type = nil
        } catch DecodingError.typeMismatch {
            let urlData = try container.decode(UrlDataDto.self)
            self.href = urlData.href
            self.type = urlData.type
            self.rel = urlData.rel
        }
    }

    public func encode(to encoder: Encoder) throws {
        if self.type != nil || self.rel != nil {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.href, forKey: .href)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.rel, forKey: .rel)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(self.href)
        }
    }
}

extension UrlDto: Equatable {
    public static func == (lhs: UrlDto, rhs: UrlDto) -> Bool {
        return lhs.href == rhs.href && lhs.type == rhs.type
    }
}

extension UrlDto: Codable { }
extension UrlDto: Sendable { }

fileprivate struct UrlDataDto {
    public let href: String
    public let type: UrlTypeDto?
    public let rel: String?
}

extension UrlDataDto: Codable { }
