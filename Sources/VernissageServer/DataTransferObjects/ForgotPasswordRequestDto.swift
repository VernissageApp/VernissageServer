//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ForgotPasswordRequestDto {
    /// Email which has been used during registration.
    var email: String
    
    /// Base url to web application. It's used to redirect from email about email to correct web application page.
    var redirectBaseUrl: String
}

extension ForgotPasswordRequestDto: Content { }

extension ForgotPasswordRequestDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("redirectBaseUrl", as: String.self, is: .url)
    }
}
