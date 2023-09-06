//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public final class ContextDto {
    public let value: String
    
    enum CodingKeys: String, CodingKey {
        case value
    }
    
    public init(value: String
    ) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self.value = try container.decode(String.self)
        } catch DecodingError.typeMismatch {
            // let objectData = try container.decode(ContextDataDto.self)
            // self.value = objectData.value
            self.value = ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
        // var container = encoder.container(keyedBy: CodingKeys.self)
        // try container.encode(self.value, forKey: .value)
    }
}

extension ContextDto: Equatable {
    public static func == (lhs: ContextDto, rhs: ContextDto) -> Bool {
        return lhs.value == rhs.value
    }
}

extension ContextDto: Codable { }

final fileprivate class ContextDataDto {
    public let value: String
}

extension ContextDataDto: Codable { }
