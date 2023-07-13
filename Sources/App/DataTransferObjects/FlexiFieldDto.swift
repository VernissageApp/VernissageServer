//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct FlexiFieldDto: Codable {
    var id: String?
    var key: String?
    var value: String?
    var isVerified: Bool?
    
    var html: String? {
        get {
            return self.value?.html()
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case key
        case value
        case isVerified
        case html
    }
    
    init(id: String? = nil, key: String?, value: String?, isVerified: Bool? = nil) {
        self.id = id
        self.key = key
        self.value = value
        self.isVerified = isVerified
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        key = try values.decodeIfPresent(String.self, forKey: .key)
        value = try values.decodeIfPresent(String.self, forKey: .value)
        isVerified = try values.decodeIfPresent(Bool.self, forKey: .isVerified)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(key, forKey: .key)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(isVerified, forKey: .isVerified)
        try container.encodeIfPresent(html, forKey: .html)
    }
}

extension FlexiFieldDto {
    init(from flexiField: FlexiField) {
        self.init(id: flexiField.stringId(),
                  key: flexiField.key,
                  value: flexiField.value,
                  isVerified: flexiField.isVerified)
    }
}

extension FlexiFieldDto: Content { }

extension FlexiFieldDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("key", as: String?.self, is: .count(...500) || .nil, required: false)
        validations.add("value", as: String?.self, is: .count(...500) || .nil, required: false)
    }
}
