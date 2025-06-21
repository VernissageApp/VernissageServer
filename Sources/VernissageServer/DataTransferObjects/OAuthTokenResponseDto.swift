//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Entity with response data from OAuth token endpint.
struct OAuthTokenResponseDto {
    var accessToken: String
    var tokenType: String
    var expiresIn: Date
    var refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

extension OAuthTokenResponseDto: Content { }
