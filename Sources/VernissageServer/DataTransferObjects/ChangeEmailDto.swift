//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ChangeEmailDto {
    /// New user's email.
    var email: String
    
    /// URL which will used in the email to redirect to correct web page.
    var redirectBaseUrl: String
}

extension ChangeEmailDto: Content { }

extension ChangeEmailDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("redirectBaseUrl", as: String.self, is: .url)
    }
}
