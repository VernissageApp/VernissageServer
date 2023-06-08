//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct SettingDto {
    var id: String?
    var key: String
    var value: String
}

extension SettingDto {
    init(from setting: Setting) {
        self.init(
            id: setting.stringId(),
            key: setting.key,
            value: setting.value
        )
    }
}

extension SettingDto: Content { }

extension SettingDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("value", as: String.self, required: true)
    }
}
