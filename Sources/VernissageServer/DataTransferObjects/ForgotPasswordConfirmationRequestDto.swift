//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ForgotPasswordConfirmationRequestDto {
    /// UUID which have been generated in previous request.
    var forgotPasswordGuid: String
    
    /// New password for the account. At least one lowercase letter, one uppercase letter, number or symbol.
    var password: String
}

extension ForgotPasswordConfirmationRequestDto: Content { }

extension ForgotPasswordConfirmationRequestDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("password", as: String.self, is: .count(8...32) && .password)
    }
}
