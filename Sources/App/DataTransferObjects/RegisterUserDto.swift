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
    var name: String?
    var bio: String?
    var location: String?
    var website: String?
    var birthDate: Date?
    var gravatarHash: String?
    var securityToken: String?
}

extension RegisterUserDto: Content { }

extension RegisterUserDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("userName", as: String.self, is: .count(1...50) && .alphanumeric)
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...32) && .password)

        validations.add("name", as: String?.self, is: .nil || .count(...50), required: false)
        validations.add("location", as: String?.self, is: .nil || .count(...50), required: false)
        validations.add("website", as: String?.self, is: .nil || .count(...50), required: false)
        validations.add("bio", as: String?.self, is: .nil || .count(...200), required: false)

        validations.add("securityToken", as: String?.self, is: !.nil)
    }
}
