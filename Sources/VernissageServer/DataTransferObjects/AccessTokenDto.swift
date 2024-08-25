//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// An entity that stores credential token data.
struct AccessTokenDto {
    /// JWT access token.
    var accessToken: String?
    
    /// Token which can be used to refresh `accessToken`.
    var refreshToken: String?
    
    /// Token which is used to prevent XSRF attacks.
    var xsrfToken: String?
    
    /// JWT acccess token expiration date.
    var expirationDate: Date
    
    /// User authorization data.
    var userPayload: UserPayload
}

extension AccessTokenDto: Content { }
