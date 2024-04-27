//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Entity that holds access tokens used in authorisations process.
struct AccessTokens {
    /// JWT access token.
    var accessToken: String
    
    /// Token which can be used to refresh `accessToken`.
    var refreshToken: String
    
    /// JWT acccess token expiration date.
    var expirationDate: Date
    
    /// User authorization data.
    var userPayload: UserPayload
    
    /// Should send tokens in cookies instead of response.
    var useCookies: Bool
}

extension AccessTokens {
    func toAccessTokenDto() -> AccessTokenDto {
        if self.useCookies {
            return AccessTokenDto(expirationDate: self.expirationDate, userPayload: self.userPayload)
        }
        
        return AccessTokenDto(accessToken: self.accessToken, refreshToken: self.refreshToken, expirationDate: self.expirationDate, userPayload: self.userPayload)
    }
}
