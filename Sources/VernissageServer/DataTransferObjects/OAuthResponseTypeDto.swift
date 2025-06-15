//
//  https://mczachurski.dev
//  Copyright © 2025 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Vapor

/// Array of the OAuth 2.0 response type strings that the client can
/// use at the authorization endpoint.  These response types are
/// defined as follows:
/// - "code": The authorization code response type defined in OAuth
/// 2.0, Section 4.1.
/// - "token": The implicit response type defined in OAuth 2.0,
/// Section 4.2.
enum OAuthResponseTypeDto: String {
    case code
    case token
}

extension OAuthResponseTypeDto: Content { }
