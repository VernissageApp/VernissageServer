//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public enum ItemKind<T>: Codable where T: Equatable, T: Codable {
    case string(String)
    case object(T)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            let value = try container.decode(T.self)
            self = .object(value)
        } catch DecodingError.typeMismatch {
            let value = try container.decode(String.self)
            self = .string(value)
        }
    }
  
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .object(let object):
            try container.encode(object)
        }
    }
}

extension ItemKind: Equatable {
}
