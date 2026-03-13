//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Response returned to the user when "urn:ietf:wg:oauth:2.0:oob" is specified as "redirect_uri".
struct OAuthCodeResponseDto {
    var code: String
    var state: String?
}

extension OAuthCodeResponseDto: Content { }
