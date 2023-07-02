//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct FlexiFieldDto {
    var id: String?
    var key: String?
    var value: String?
    var isVerified: Bool?
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
