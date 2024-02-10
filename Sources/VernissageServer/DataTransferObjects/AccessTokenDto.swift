//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct AccessTokenDto {
    /// JWT access token.
    var accessToken: String
    
    /// Token which can be used to refresh `accessToken`.
    var refreshToken: String
}

extension AccessTokenDto: Content { }
