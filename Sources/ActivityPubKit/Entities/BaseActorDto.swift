//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public struct BaseActorDto {
    public let id: String
    public let type: ActorTypeDto?
    public let name: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
    }
    
    public init(id: String, type: ActorTypeDto? = nil, name: String? = nil) {
        self.id = id
        self.type = type
        self.name = name
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self.id = try container.decode(String.self)
            self.name = nil
            self.type = nil
        } catch DecodingError.typeMismatch {
            let actorData = try container.decode(BaseActorDataDto.self)
            self.id = actorData.id
            self.type = actorData.type
            self.name = actorData.name
        }
    }

    public func encode(to encoder: Encoder) throws {
        if self.type != nil || self.name != nil {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.id, forKey: .id)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.name, forKey: .name)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(self.id)
        }
    }
}

extension BaseActorDto: Equatable {
    public static func == (lhs: BaseActorDto, rhs: BaseActorDto) -> Bool {
        return lhs.id == rhs.id && lhs.type == rhs.type
    }
}

extension BaseActorDto: Codable { }

fileprivate struct BaseActorDataDto {
    public let id: String
    public let type: ActorTypeDto?
    public let name: String?
}

extension BaseActorDataDto: Codable { }
