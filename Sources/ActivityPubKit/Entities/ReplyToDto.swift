//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct ReplyToDto {
    public let id: String
    public let url: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case url
    }
    
    public init(id: String, url: String? = nil) {
        self.id = id
        self.url = url
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self.id = try container.decode(String.self)
            self.url = nil
        } catch DecodingError.typeMismatch {
            let replyToData = try container.decode(ReplyToDataDto.self)
            self.id = replyToData.id
            self.url = replyToData.url
        }
    }

    public func encode(to encoder: Encoder) throws {
        if self.url != nil {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.id, forKey: .id)
            try container.encode(self.url, forKey: .url)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(self.id)
        }
    }
}

extension ReplyToDto: Equatable {
    public static func == (lhs: ReplyToDto, rhs: ReplyToDto) -> Bool {
        return lhs.id == rhs.id && lhs.id == rhs.id
    }
}

extension ReplyToDto: Codable { }
extension ReplyToDto: Sendable { }

fileprivate struct ReplyToDataDto {
    public let id: String
    public let url: String?
}

extension ReplyToDataDto: Codable { }
