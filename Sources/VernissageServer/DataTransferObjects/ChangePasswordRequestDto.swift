//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct ChangePasswordRequestDto {
    /// Old password for the account.
    var currentPassword: String
    
    /// New password for the account. At least one lowercase letter, one uppercase letter, number or symbol.
    var newPassword: String
}

extension ChangePasswordRequestDto: Content { }

extension ChangePasswordRequestDto: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("newPassword", as: String.self, is: .count(8...32) && .password)
    }
}
