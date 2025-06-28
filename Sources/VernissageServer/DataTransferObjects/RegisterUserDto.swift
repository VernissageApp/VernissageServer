//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct RegisterUserDto {
    /// User name of the new user.
    var userName: String
    
    /// Email address of the new user.
    var email: String
    
    /// Password for the new account. At least one lowercase letter, one uppercase letter, number or symbol.
    var password: String
    
    /// Base url to web application. It's used to redirect from email about email confirmation to correct web application page.
    var redirectBaseUrl: String
    
    /// Information if user accepted the server rules. Only request with `true` as a value can be procesed.
    var agreement: Bool
    
    /// Full name of the user.
    var name: String?
    
    /// Token for captcha (combined: `key/text`).
    var securityToken: String?
    
    /// Locale with format like: `en_US`, `en_GB`, `pl_PL` etc. This will be used to prepare email for confirmation email message.
    var locale: String?
    
    /// When registartion by moderator approval is enabled (and open registration is disabled) user have to write reason why account for him should be created.
    var reason: String?
    
    /// When registration by invitation is enabled (and open registration is disabled) the invitation token have to be specified.
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
