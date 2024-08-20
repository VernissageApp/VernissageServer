//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct LoginRequestDto {
    /// User name or email.
    var userNameOrEmail: String
    
    /// Password.
    var password: String
    
    /// Should set cookie instead of returning tokens in response body.
    var useCookies: Bool? = false
    
    /// Machine is trusted  (we don't have to ask for 2FA token for 30 days).
    var trustMachine: Bool? = false
}

extension LoginRequestDto: Content { }
