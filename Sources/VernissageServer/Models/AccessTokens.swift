//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Entity that holds access tokens used in authorisations process.
struct AccessTokens {
    /// JWT access token.
    var accessToken: String
    
    /// Token which can be used to refresh `accessToken`.
    var refreshToken: String
    
    /// Token which is used to prevent XSRF attacks.
    var xsrfToken: String
    
    /// JWT acccess token expiration date.
    var accessTokenExpirationDate: Date

    /// Refresh token expiration date.
    var refreshTokenExpirationDate: Date
    
    /// User authorization data.
    var userPayload: UserPayload
    
    /// Should send tokens in cookies instead of response.
    var useCookies: Bool
}

extension AccessTokens {
    func toAccessTokenDto() -> AccessTokenDto {
        if self.useCookies {
            return AccessTokenDto(xsrfToken: self.xsrfToken,
                                  expirationDate: self.accessTokenExpirationDate,
                                  userPayload: self.userPayload)
        }
        
        return AccessTokenDto(accessToken: self.accessToken,
                              refreshToken: self.refreshToken,
                              expirationDate: self.accessTokenExpirationDate,
                              userPayload: self.userPayload)
    }
}
