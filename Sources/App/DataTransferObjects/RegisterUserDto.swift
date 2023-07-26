//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct RegisterUserDto {
    var userName: String
    var email: String
    var password: String
    var redirectBaseUrl: String
    var agreement: Bool
    var name: String?
    var securityToken: String?
    var locale: String?
    var reason: String?
    var inviteToken: String?
}

extension RegisterUserDto: Content { }

extension RegisterUserDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("userName", as: String.self, is: .count(1...50) && .alphanumeric)
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...32) && .password)
        validations.add("redirectBaseUrl", as: String.self, is: .url)

        validations.add("name", as: String?.self, is: .nil || .count(...100), required: false)
        validations.add("locale", as: String?.self, is: .nil || .count(5...5), required: false)
        validations.add("reason", as: String?.self, is: .nil || .count(...500), required: false)

        validations.add("securityToken", as: String?.self, is: !.nil)
    }
}
