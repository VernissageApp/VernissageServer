//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct RefreshTokenDto {
    /// Refresh token set up during the login process.
    var refreshToken: String
    
    ///  Regenerate token value in database.
    var regenerateRefreshToken: Bool? = true
    
    /// Should set cookie instead of returning tokens in response body.
    var useCookies: Bool? = false
}

extension RefreshTokenDto: Content { }
