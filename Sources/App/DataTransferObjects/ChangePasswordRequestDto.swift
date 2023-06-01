//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ChangePasswordRequestDto {
    var currentPassword: String
    var newPassword: String
}

extension ChangePasswordRequestDto: Content { }

extension ChangePasswordRequestDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("newPassword", as: String.self, is: .count(8...32) && .password)
    }
}
