//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public protocol CommonObjectDto: Codable {
}


public final class ObjectDto {
    public let id: String
    public let type: ObjectTypeDto?
    public let name: String?
    public let object: CommonObjectDto?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
    }
    
    public init(id: String,
                type: ObjectTypeDto? = nil,
                name: String? = nil,
                object: CommonObjectDto? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.object = object
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self.id = try container.decode(String.self)
            self.type = nil
            self.name = nil
            self.object = nil
        } catch DecodingError.typeMismatch {
            let objectData = try container.decode(ObjectDataDto.self)
            self.id = objectData.id
            self.type = objectData.type
            self.name = objectData.name
            
            switch self.type {
            case .note:
                self.object = try NoteDto(from: decoder)
            case .follow:
                self.object = try FollowDto(from: decoder)
            default:
                self.object = nil
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        if self.type != nil || self.name != nil || self.object != nil {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.id, forKey: .id)
            
            try container.encodeIfPresent(self.type, forKey: .type)
            try container.encodeIfPresent(self.name, forKey: .name)
            
            if let object {
                try object.encode(to: encoder)
            }
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(self.id)
        }
    }
}

extension ObjectDto: Equatable {
    public static func == (lhs: ObjectDto, rhs: ObjectDto) -> Bool {
        return lhs.id == rhs.id && lhs.type == rhs.type
    }
}

extension ObjectDto: Codable { }

final fileprivate class ObjectDataDto {
    public let id: String
    public let type: ObjectTypeDto?
    public let name: String?
}

extension ObjectDataDto: Codable { }
