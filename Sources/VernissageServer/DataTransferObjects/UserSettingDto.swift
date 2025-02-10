//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Fluent
import Vapor

/// User's setting.
struct UserSettingDto {
    var key: String
    var value: String
}

extension UserSettingDto: Content { }
