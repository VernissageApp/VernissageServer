//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct BaseObjectDto: Content {
    public let id: String
    public let type: ObjectTypeDto
    public let name: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
    }
    
    public init(id: String, type: ObjectTypeDto, name: String? = nil) {
        self.id = id
        self.type = type
        self.name = name
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self.id = try container.decode(String.self)
            self.type = .profile
            self.name = nil
        } catch DecodingError.typeMismatch {
            let objectData = try container.decode(BaseObjectDataDto.self)
            self.id = objectData.id
            self.type = objectData.type
            self.name = objectData.name
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.id)
    }
}

extension BaseObjectDto: Equatable {
    static func == (lhs: BaseObjectDto, rhs: BaseObjectDto) -> Bool {
        return lhs.id == rhs.id && lhs.type == rhs.type
    }
}

fileprivate struct BaseObjectDataDto: Content {
    public let id: String
    public let type: ObjectTypeDto
    public let name: String?
}
