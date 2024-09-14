//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

public final class ContextDto {
    public let value: String?
    public let manuallyApprovesFollowers: String?
    public let toot: String?
    public let schema: String?
    public let propertyValue: String?
    public let alsoKnownAs: AlsoKnownAs?
    
    enum CodingKeys: String, CodingKey {
        case value
        case manuallyApprovesFollowers
        case toot
        case schema
        case propertyValue = "PropertyValue"
        case alsoKnownAs
    }
    
    public init(value: String) {
        self.value = value
        self.manuallyApprovesFollowers = nil
        self.toot = nil
        self.alsoKnownAs = nil
        self.schema = nil
        self.propertyValue = nil
    }
    
    public init(manuallyApprovesFollowers: String, toot: String, schema: String, propertyValue: String, alsoKnownAs: AlsoKnownAs) {
        self.value = nil
        self.manuallyApprovesFollowers = manuallyApprovesFollowers
        self.toot = toot
        self.alsoKnownAs = alsoKnownAs
        self.schema = schema
        self.propertyValue = propertyValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            self.value = try container.decode(String.self)
            self.manuallyApprovesFollowers = nil
            self.toot = nil
            self.alsoKnownAs = nil
            self.schema = nil
            self.propertyValue = nil
        } catch DecodingError.typeMismatch {
            if let objectData = try? container.decode(ContextDataDto.self) {
                self.value = ""
                self.manuallyApprovesFollowers = objectData.manuallyApprovesFollowers
                self.toot = objectData.toot
                self.alsoKnownAs = objectData.alsoKnownAs
                self.schema = objectData.schema
                self.propertyValue = objectData.propertyValue
            } else {
                self.value = nil
                self.manuallyApprovesFollowers = nil
                self.toot = nil
                self.alsoKnownAs = nil
                self.schema = nil
                self.propertyValue = nil
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        if self.value == nil {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.manuallyApprovesFollowers, forKey: .manuallyApprovesFollowers)
            try container.encode(self.toot, forKey: .toot)
            try container.encode(self.schema, forKey: .schema)
            try container.encode(self.propertyValue, forKey: .propertyValue)
            try container.encode(self.alsoKnownAs, forKey: .alsoKnownAs)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(self.value)
        }
    }
}

extension ContextDto: Equatable {
    public static func == (lhs: ContextDto, rhs: ContextDto) -> Bool {
        return lhs.value == rhs.value
    }
}

extension ContextDto: Codable { }
extension ContextDto: Sendable { }

final fileprivate class ContextDataDto {
    public let manuallyApprovesFollowers: String?
    public let toot: String?
    public let schema: String?
    public let propertyValue: String?
    public let alsoKnownAs: AlsoKnownAs?
    
    enum CodingKeys: String, CodingKey {
        case manuallyApprovesFollowers
        case toot
        case schema
        case propertyValue = "PropertyValue"
        case alsoKnownAs
    }
}

extension ContextDataDto: Codable { }

public final class AlsoKnownAs: Sendable {
    public let id: String?
    public let type: String?
    
    init(id: String?, type: String?) {
        self.id = id
        self.type = type
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "@id"
        case type = "@type"
    }
}

extension AlsoKnownAs: Codable { }
