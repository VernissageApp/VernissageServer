//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct BaseActorDto: Content {
    public let id: String
    public let type: ActorTypeDto
    public let name: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
    }
    
    public init(id: String, type: ActorTypeDto, name: String? = nil) {
        self.id = id
        self.type = type
        self.name = name
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self.id = try container.decode(String.self)
            self.name = nil
            self.type = .person
        } catch DecodingError.typeMismatch {
            let actorData = try container.decode(BaseActorDataDto.self)
            self.id = actorData.id
            self.type = actorData.type
            self.name = actorData.name
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.id)
    }
}

extension BaseActorDto: Equatable {
    static func == (lhs: BaseActorDto, rhs: BaseActorDto) -> Bool {
        return lhs.id == rhs.id && lhs.type == rhs.type
    }
}

fileprivate struct BaseActorDataDto: Content {
    public let id: String
    public let type: ActorTypeDto
    public let name: String?
}
