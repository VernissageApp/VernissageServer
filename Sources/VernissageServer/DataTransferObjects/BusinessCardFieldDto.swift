//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct BusinessCardFieldDto {
    var id: String?
    var key: String
    var value: String
    var createdAt: Date?
    var updatedAt: Date?
}

extension BusinessCardFieldDto {
    init(from businessCardField: BusinessCardField) {
        self.init(id: businessCardField.stringId(),
                  key: businessCardField.key,
                  value: businessCardField.value,
                  createdAt: businessCardField.createdAt,
                  updatedAt: businessCardField.updatedAt)
    }
}

extension BusinessCardFieldDto: Content { }

extension BusinessCardFieldDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("key", as: String.self, is: .count(1...200), required: true)
        validations.add("value", as: String.self, is: .count(1...500), required: true)
    }
}
