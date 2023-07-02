//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ChangeEmailDto {
    var email: String
    var redirectBaseUrl: String
}

extension ChangeEmailDto: Content { }

extension ChangeEmailDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("redirectBaseUrl", as: String.self, is: .url)
    }
}
