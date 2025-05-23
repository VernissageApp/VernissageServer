//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

/// This is struct which can hold several types of JSON structure, like:
///
///  - single string:
///  ```swift
///  "actor": "https://johndoe.example.com"
///  ```
///
///  - array of strings:
///  ```swift
///  "actor": ["https://johndoe.example.com", "https://annadoe.example.com"]
///  ```
///
///  - sigle object:
///  ```swift
///  "actor": {
///    "id": "https://johndoe.example.com",
///    "type": "Person",
///    "name": "John Doe"
///  }
///  ```
///
///  - array of objects:
///  ```swift
///  "actor": [{
///      "id": "https://johndoe.example.com",
///      "type": "Person",
///      "name": "John Doe"
///    }, {
///      "id": "https://annadoe.example.com",
///      "type": "Person",
///      "name": "Anna Doe"
///    }
///  ]
///  ```
///
///  - mixed arrays:
///
///  ```swift
///  "actor": [
///    "https://johndoe.example.com",
///    {
///      "id": "https://annadoe.example.com",
///      "type": "Person",
///      "name": "Anna Doe"
///    }
///  ]
///  ```
public enum ComplexType<T>: Codable, Sendable where T: Equatable, T: Codable, T: Sendable {
    case single(T)
    case multiple([T])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            let value = try container.decode([T].self)
            self = .multiple(value)
        } catch DecodingError.typeMismatch {
            let value = try container.decode(T.self)
            self = .single(value)
        }
    }
  
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let single):
            try container.encode(single)
        case .multiple(let multiple):
            try container.encode(multiple)
        }
    }
}

extension ComplexType: Equatable {
    public static func == (lhs: ComplexType, rhs: ComplexType) -> Bool {
        switch (lhs, rhs) {
        case (.single(let lid), .single(let rid)):
            return lid == rid
        case (.multiple(let larr), .multiple(let rarr)):
            if larr.count == 0 && rarr.count == 0 {
                return true
            }
            
            if larr.count != rarr.count {
                return false
            }
            
            for (index, lelem) in larr.enumerated() {
                if lelem != rarr[index] {
                    return false
                }
            }
            
            return true
        default:
            return false
        }
    }
}

extension ComplexType<String> {
    public func values() -> [String] {
        var values: [String] = []
        
        switch self {
        case .single(let singleValue):
            values.append(singleValue)
        case .multiple(let multipleValues):
            for singleValue in multipleValues {
                values.append(singleValue)
            }
        }
        
        return values
    }
}
