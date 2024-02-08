//
//  https://mczachurski.dev
//  Copyright © 2023 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

struct OAuthResponse: Content {
    enum CodingKeys: String, CodingKey {
        case scope
        case idToken = "id_token"
        case tokenType = "token_type"
        case refreshToken = "refresh_token"
    }

    var idToken: String?
    var scope: String?
    var tokenType: String?
    var refreshToken: String?
}
