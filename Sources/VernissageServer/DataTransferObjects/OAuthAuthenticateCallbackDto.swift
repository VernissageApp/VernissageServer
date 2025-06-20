//
//  https://mczachurski.dev
//  Copyright © 2024 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Entity used in the authorize page callback.
struct OAuthAuthenticateCallbackDto {
    var id: String
    var csrfToken: String
    var state: String
}

extension OAuthAuthenticateCallbackDto: Content { }
