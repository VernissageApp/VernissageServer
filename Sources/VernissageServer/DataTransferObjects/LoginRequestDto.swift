//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LoginRequestDto {
    /// User name or email.
    var userNameOrEmail: String
    
    /// Password.
    var password: String
}

extension LoginRequestDto: Content { }
